import Foundation
import SwiftUI
import Combine

public enum MenuBarDisplayMode: String, CaseIterable, Codable {
    case countdownAndIcon = "Icon & Waqt Countdown"
    case prayerAndIcon = "Icon & Current Prayer"
    case iconOnly = "Icon Only"
}

public enum MenuBarIconStyle: String, CaseIterable, Codable {
    case mosqueVector = "Mosque (Native Mac Style)"
    case dynamicWaqt = "Crescent & Sun (Dynamic)"
    case appColorLogo = "Color App Badge"
}

public final class PrayerStore: ObservableObject {
    public static let shared = PrayerStore()

    private let defaults = UserDefaults.standard
    private let engine = PrayerEngine.shared
    private let notifications = NotificationHelper.shared

    // Location State
    @Published public var latitude: Double
    @Published public var longitude: Double
    @Published public var cityName: String
    @Published public var countryName: String

    // Current State
    @Published public var currentDate: Date
    @Published public var dailyTimes: DailyPrayerTimes
    @Published public var waqtState: WaqtState

    // Trackers
    @Published public var completedToday: [PrayerType: Bool] = [:]
    @Published public var kazaCounts: [PrayerType: Int] = [:]
    @Published public var processedMissedToday: [PrayerType: Bool] = [:]
    @Published public var notifiedStartedToday: [PrayerType: Bool] = [:]

    // Period / Haidh Exemption Mode
    @Published public var isPeriodModeActive: Bool {
        didSet {
            defaults.set(isPeriodModeActive, forKey: "isPeriodModeActive")
        }
    }
    @Published public var periodStartDate: Date? {
        didSet {
            defaults.set(periodStartDate, forKey: "periodStartDate")
        }
    }

    // Settings & UI state
    @Published public var showingSettings: Bool = false
    @Published public var asrMethod: AsrMethod {
        didSet {
            defaults.set(asrMethod.rawValue, forKey: "asrMethod")
            refreshTimes()
        }
    }

    @Published public var menuBarMode: MenuBarDisplayMode {
        didSet {
            defaults.set(menuBarMode.rawValue, forKey: "menuBarMode")
        }
    }

    @Published public var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            defaults.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle")
        }
    }

    public var currentTimeZone: TimeZone {
        return TimeZone.current
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = currentTimeZone
        return formatter.string(from: currentDate)
    }

    private init() {
        let initialMethod: AsrMethod
        if let savedMethod = defaults.string(forKey: "asrMethod"), let method = AsrMethod(rawValue: savedMethod) {
            initialMethod = method
        } else {
            initialMethod = .hanafi
        }
        self.asrMethod = initialMethod

        let initialMode: MenuBarDisplayMode
        if let savedMode = defaults.string(forKey: "menuBarMode"), let mode = MenuBarDisplayMode(rawValue: savedMode) {
            initialMode = mode
        } else {
            initialMode = .countdownAndIcon
        }
        self.menuBarMode = initialMode

        let initialIconStyle: MenuBarIconStyle
        if let savedIconStyle = defaults.string(forKey: "menuBarIconStyle"), let style = MenuBarIconStyle(rawValue: savedIconStyle) {
            initialIconStyle = style
        } else {
            initialIconStyle = .mosqueVector
        }
        self.menuBarIconStyle = initialIconStyle

        // Load Period Mode State
        self.isPeriodModeActive = defaults.bool(forKey: "isPeriodModeActive")
        self.periodStartDate = defaults.object(forKey: "periodStartDate") as? Date

        // Load cached location or default to Dhaka
        let cachedLat = defaults.double(forKey: "lastLatitude")
        let cachedLon = defaults.double(forKey: "lastLongitude")
        let cachedCity = defaults.string(forKey: "lastCityName")
        let cachedCountry = defaults.string(forKey: "lastCountryName")

        let lat = (cachedLat != 0.0) ? cachedLat : 23.8103
        let lon = (cachedLon != 0.0) ? cachedLon : 90.4125
        self.latitude = lat
        self.longitude = lon
        self.cityName = cachedCity ?? "Dhaka"
        self.countryName = cachedCountry ?? "Bangladesh"

        let now = Date()
        let times = engine.calculateDailyTimes(for: now, latitude: lat, longitude: lon, timeZone: TimeZone.current, asrMethod: initialMethod)
        self.currentDate = now
        self.dailyTimes = times
        self.waqtState = engine.getCurrentWaqt(now: now, dailyTimes: times)

        loadDailyState()
        loadKazaCounts()
    }

    public func setPeriodMode(enabled: Bool) {
        isPeriodModeActive = enabled
        if enabled {
            if periodStartDate == nil {
                periodStartDate = Date()
            }
        } else {
            periodStartDate = nil
        }
    }

    public func togglePeriodMode() {
        setPeriodMode(enabled: !isPeriodModeActive)
    }

    public var periodDaysActive: Int {
        guard let start = periodStartDate else { return 1 }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let currentDay = calendar.startOfDay(for: Date())
        let diff = calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0
        return max(1, diff + 1)
    }

    public func onLocationUpdated(latitude: Double, longitude: Double, cityName: String, countryName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self.countryName = countryName

        refreshTimes()
    }

    public func refreshTimes() {
        let now = Date()
        self.currentDate = now
        self.dailyTimes = engine.calculateDailyTimes(
            for: now,
            latitude: self.latitude,
            longitude: self.longitude,
            timeZone: self.currentTimeZone,
            asrMethod: self.asrMethod
        )
        self.waqtState = engine.getCurrentWaqt(now: now, dailyTimes: self.dailyTimes)
    }

    private func loadDailyState() {
        let today = dayString
        let savedDate = defaults.string(forKey: "lastActiveDate") ?? ""

        if savedDate != today {
            var freshCompleted: [PrayerType: Bool] = [:]
            var freshMissed: [PrayerType: Bool] = [:]
            var freshNotified: [PrayerType: Bool] = [:]

            for p in PrayerType.allCases {
                freshCompleted[p] = false
                freshMissed[p] = false
                freshNotified[p] = false
            }

            self.completedToday = freshCompleted
            self.processedMissedToday = freshMissed
            self.notifiedStartedToday = freshNotified

            defaults.set(today, forKey: "lastActiveDate")
            saveDailyCompleted()
            saveDailyFlags()
        } else {
            if let saved = defaults.dictionary(forKey: "completedToday_\(today)") as? [String: Bool] {
                var map: [PrayerType: Bool] = [:]
                for p in PrayerType.allCases { map[p] = saved[p.rawValue] ?? false }
                self.completedToday = map
            } else {
                var map: [PrayerType: Bool] = [:]
                for p in PrayerType.allCases { map[p] = false }
                self.completedToday = map
            }

            if let saved = defaults.dictionary(forKey: "processedMissed_\(today)") as? [String: Bool] {
                var map: [PrayerType: Bool] = [:]
                for p in PrayerType.allCases { map[p] = saved[p.rawValue] ?? false }
                self.processedMissedToday = map
            } else {
                var map: [PrayerType: Bool] = [:]
                for p in PrayerType.allCases { map[p] = false }
                self.processedMissedToday = map
            }

            if let saved = defaults.dictionary(forKey: "notifiedStarted_\(today)") as? [String: Bool] {
                var map: [PrayerType: Bool] = [:]
                for p in PrayerType.allCases { map[p] = saved[p.rawValue] ?? false }
                self.notifiedStartedToday = map
            } else {
                var map: [PrayerType: Bool] = [:]
                for p in PrayerType.allCases { map[p] = false }
                self.notifiedStartedToday = map
            }
        }
    }

    private func saveDailyCompleted() {
        var dict: [String: Bool] = [:]
        for (k, v) in completedToday { dict[k.rawValue] = v }
        defaults.set(dict, forKey: "completedToday_\(dayString)")
    }

    private func saveDailyFlags() {
        var missedDict: [String: Bool] = [:]
        for (k, v) in processedMissedToday { missedDict[k.rawValue] = v }
        defaults.set(missedDict, forKey: "processedMissed_\(dayString)")

        var startedDict: [String: Bool] = [:]
        for (k, v) in notifiedStartedToday { startedDict[k.rawValue] = v }
        defaults.set(startedDict, forKey: "notifiedStarted_\(dayString)")
    }

    private func loadKazaCounts() {
        if let saved = defaults.dictionary(forKey: "kazaCounts") as? [String: Int] {
            var map: [PrayerType: Int] = [:]
            for p in PrayerType.allCases { map[p] = max(0, saved[p.rawValue] ?? 0) }
            self.kazaCounts = map
        } else {
            var map: [PrayerType: Int] = [:]
            for p in PrayerType.allCases { map[p] = 0 }
            self.kazaCounts = map
        }
    }

    public func saveKazaCounts() {
        var dict: [String: Int] = [:]
        for (k, v) in kazaCounts { dict[k.rawValue] = v }
        defaults.set(dict, forKey: "kazaCounts")
    }

    public func togglePrayer(_ prayer: PrayerType) {
        let current = completedToday[prayer] ?? false
        let updated = !current
        completedToday[prayer] = updated
        saveDailyCompleted()

        if updated && (processedMissedToday[prayer] ?? false) {
            if let currentKaza = kazaCounts[prayer], currentKaza > 0 {
                kazaCounts[prayer] = currentKaza - 1
                saveKazaCounts()
            }
        }
    }

    public func incrementKaza(for prayer: PrayerType) {
        let count = kazaCounts[prayer] ?? 0
        kazaCounts[prayer] = count + 1
        saveKazaCounts()
    }

    public func decrementKaza(for prayer: PrayerType) {
        let count = kazaCounts[prayer] ?? 0
        if count > 0 {
            kazaCounts[prayer] = count - 1
            saveKazaCounts()
        }
    }

    public var totalKaza: Int {
        kazaCounts.values.reduce(0, +)
    }

    public func tick() {
        let now = Date()
        self.currentDate = now
        self.waqtState = engine.getCurrentWaqt(now: now, dailyTimes: dailyTimes)
        checkWaqtTransitions(now: now)
    }

    private func checkWaqtTransitions(now: Date) {
        let today = dayString
        let savedDate = defaults.string(forKey: "lastActiveDate") ?? ""
        if savedDate != today {
            loadDailyState()
            refreshTimes()
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        timeFormatter.timeZone = currentTimeZone

        // 1. Check for Prayer Start Notifications
        for prayer in PrayerType.allCases {
            let startTime = dailyTimes.time(for: prayer)
            let endTime = dailyTimes.endTime(for: prayer)

            if now >= startTime && now < endTime {
                let alreadyNotified = notifiedStartedToday[prayer] ?? false
                if !alreadyNotified {
                    notifiedStartedToday[prayer] = true
                    saveDailyFlags()

                    // If Period Mode is active, silence waqt start alerts (user requested)
                    if !isPeriodModeActive {
                        let timeStr = timeFormatter.string(from: startTime)
                        notifications.sendNotification(
                            title: "🕌 \(prayer.rawValue) Waqt Started",
                            subtitle: "\(cityName), \(countryName)",
                            body: "It is now \(prayer.rawValue) time (\(timeStr)). Have you prepared for namaz?",
                            identifier: "start_\(prayer.rawValue)_\(today)"
                        )
                    }
                }
            }
        }

        // 2. Check for Missed Prayer / Kaza Trigger
        for prayer in PrayerType.allCases {
            let endTime = dailyTimes.endTime(for: prayer)

            if now >= endTime {
                let isCompleted = completedToday[prayer] ?? false
                let alreadyProcessed = processedMissedToday[prayer] ?? false

                if !isCompleted && !alreadyProcessed {
                    processedMissedToday[prayer] = true

                    // If Period Mode is active, prayers are exempted: NO KAZA & NO MISSED NOTIFICATION
                    if !isPeriodModeActive {
                        let currentKaza = kazaCounts[prayer] ?? 0
                        kazaCounts[prayer] = currentKaza + 1
                        saveKazaCounts()
                        saveDailyFlags()

                        notifications.sendNotification(
                            title: "⚠️ Missed Prayer Reminder",
                            subtitle: "\(prayer.rawValue) Waqt has ended",
                            body: "You have missed \(prayer.rawValue) prayer. Mark it if completed or pray the kaza namaz.",
                            identifier: "missed_\(prayer.rawValue)_\(today)"
                        )
                    } else {
                        saveDailyFlags()
                    }
                }
            }
        }
    }

    public func triggerTestMissedNotification() {
        if isPeriodModeActive {
            notifications.sendNotification(
                title: "🌸 Period Mode Active",
                subtitle: "Kaza Exemption",
                body: "Missed prayer alerts and Kaza counters are paused while Period Mode is enabled.",
                identifier: "test_missed_\(UUID().uuidString)"
            )
        } else {
            notifications.sendNotification(
                title: "⚠️ Missed Prayer Reminder",
                subtitle: "Dhuhr Waqt has ended",
                body: "You have missed Dhuhr prayer. Mark it if completed or pray the kaza namaz.",
                identifier: "test_missed_\(UUID().uuidString)"
            )
        }
    }

    public func triggerTestStartNotification() {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        timeFormatter.timeZone = currentTimeZone
        let timeStr = timeFormatter.string(from: Date())

        notifications.sendNotification(
            title: "🕌 Asr Waqt Started",
            subtitle: "\(cityName), \(countryName)",
            body: "It is now Asr time (\(timeStr)). Have you prepared for namaz?",
            identifier: "test_start_\(UUID().uuidString)"
        )
    }
}
