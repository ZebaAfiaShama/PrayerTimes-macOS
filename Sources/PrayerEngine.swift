import Foundation

public enum PrayerType: String, CaseIterable, Codable, Identifiable {
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .fajr: return "sun.horizon.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.and.horizon.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }

    public var localizedBanglaName: String {
        switch self {
        case .fajr: return "ফজর"
        case .dhuhr: return "যোহর"
        case .asr: return "আসর"
        case .maghrib: return "মাগরিব"
        case .isha: return "এশা"
        }
    }
}

public enum AsrMethod: String, CaseIterable, Codable {
    case hanafi = "Hanafi"
    case shafi = "Shafi'i / Standard"

    public var shadowFactor: Double {
        switch self {
        case .hanafi: return 2.0
        case .shafi: return 1.0
        }
    }
}

public struct DailyPrayerTimes {
    public let date: Date
    public let fajr: Date
    public let sunrise: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    public let nextFajr: Date

    public func time(for prayer: PrayerType) -> Date {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }

    public func endTime(for prayer: PrayerType) -> Date {
        switch prayer {
        case .fajr: return sunrise
        case .dhuhr: return asr
        case .asr: return maghrib
        case .maghrib: return isha
        case .isha: return nextFajr
        }
    }
}

public struct WaqtState {
    public let activePrayer: PrayerType?
    public let nextPrayer: PrayerType
    public let targetDate: Date
    public let remainingSeconds: TimeInterval
    public let totalSeconds: TimeInterval
    public let progress: Double
    public let isBetweenSunriseAndDhuhr: Bool

    public var countdownFormatted: String {
        let secs = max(0, Int(remainingSeconds))
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let seconds = secs % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    public var shortRemainingText: String {
        let secs = max(0, Int(remainingSeconds))
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}

public final class PrayerEngine {
    public static let shared = PrayerEngine()

    // Default fallback coordinates (Dhaka)
    public static let defaultLatitude: Double = 23.8103
    public static let defaultLongitude: Double = 90.4125

    // Karachi / Islamic Foundation Bangladesh method angles
    public let fajrAngle: Double = 18.0
    public let ishaAngle: Double = 18.0

    private func dtr(_ d: Double) -> Double { d * .pi / 180.0 }
    private func rtd(_ r: Double) -> Double { r * 180.0 / .pi }
    private func fixHour(_ a: Double) -> Double {
        var a = a.truncatingRemainder(dividingBy: 24.0)
        if a < 0 { a += 24.0 }
        return a
    }
    private func fixAngle(_ a: Double) -> Double {
        var a = a.truncatingRemainder(dividingBy: 360.0)
        if a < 0 { a += 360.0 }
        return a
    }

    public func calculateDailyTimes(
        for date: Date,
        latitude: Double = defaultLatitude,
        longitude: Double = defaultLongitude,
        timeZone: TimeZone = .current,
        asrMethod: AsrMethod = .hanafi,
        minuteOffsets: [PrayerType: Int] = [:]
    ) -> DailyPrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comp.year, let month = comp.month, let day = comp.day else {
            fatalError("Invalid date components")
        }

        let tzOffset = Double(timeZone.secondsFromGMT(for: date)) / 3600.0

        let rawToday = computeAstronomicalHours(
            year: year,
            month: month,
            day: day,
            latitude: latitude,
            longitude: longitude,
            tzOffset: tzOffset,
            asrMethod: asrMethod
        )

        // Compute next day's Fajr for Isha end-time
        let nextDayDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        let nextDayComp = calendar.dateComponents([.year, .month, .day], from: nextDayDate)
        let nextTzOffset = Double(timeZone.secondsFromGMT(for: nextDayDate)) / 3600.0
        let rawNextDay = computeAstronomicalHours(
            year: nextDayComp.year!,
            month: nextDayComp.month!,
            day: nextDayComp.day!,
            latitude: latitude,
            longitude: longitude,
            tzOffset: nextTzOffset,
            asrMethod: asrMethod
        )

        func makeDate(baseComp: DateComponents, hourFraction: Double, offsetMinutes: Int) -> Date {
            let totalSeconds = Int(round(hourFraction * 3600.0)) + (offsetMinutes * 60)
            let hour = (totalSeconds / 3600) % 24
            let minute = (totalSeconds % 3600) / 60
            let second = totalSeconds % 60

            var finalComp = baseComp
            finalComp.hour = hour
            finalComp.minute = minute
            finalComp.second = second
            return calendar.date(from: finalComp) ?? date
        }

        let fajrDate = makeDate(baseComp: comp, hourFraction: rawToday.fajr, offsetMinutes: minuteOffsets[.fajr] ?? 0)
        let sunriseDate = makeDate(baseComp: comp, hourFraction: rawToday.sunrise, offsetMinutes: 0)
        let dhuhrDate = makeDate(baseComp: comp, hourFraction: rawToday.dhuhr, offsetMinutes: minuteOffsets[.dhuhr] ?? 0)
        let asrDate = makeDate(baseComp: comp, hourFraction: rawToday.asr, offsetMinutes: minuteOffsets[.asr] ?? 0)
        let maghribDate = makeDate(baseComp: comp, hourFraction: rawToday.maghrib, offsetMinutes: minuteOffsets[.maghrib] ?? 0)
        let ishaDate = makeDate(baseComp: comp, hourFraction: rawToday.isha, offsetMinutes: minuteOffsets[.isha] ?? 0)
        let nextFajrDate = makeDate(baseComp: nextDayComp, hourFraction: rawNextDay.fajr, offsetMinutes: minuteOffsets[.fajr] ?? 0)

        return DailyPrayerTimes(
            date: date,
            fajr: fajrDate,
            sunrise: sunriseDate,
            dhuhr: dhuhrDate,
            asr: asrDate,
            maghrib: maghribDate,
            isha: ishaDate,
            nextFajr: nextFajrDate
        )
    }

    private func computeAstronomicalHours(
        year: Int,
        month: Int,
        day: Int,
        latitude: Double,
        longitude: Double,
        tzOffset: Double,
        asrMethod: AsrMethod
    ) -> (fajr: Double, sunrise: Double, dhuhr: Double, asr: Double, maghrib: Double, isha: Double) {
        var y = Double(year)
        var m = Double(month)
        let dVal = Double(day)

        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(y / 100.0)
        let b = 2.0 - a + floor(a / 4.0)
        let jd = floor(365.25 * (y + 4716.0)) + floor(30.6001 * (m + 1.0)) + dVal + b - 1524.5
        let d = jd - 2451545.0

        let g = fixAngle(357.529 + 0.98560028 * d)
        let q = fixAngle(280.459 + 0.98564736 * d)
        let l = fixAngle(q + 1.915 * sin(dtr(g)) + 0.020 * sin(dtr(2 * g)))
        let e = 23.439 - 0.00000036 * d
        let decl = rtd(asin(sin(dtr(e)) * sin(dtr(l))))
        var ra = rtd(atan2(cos(dtr(e)) * sin(dtr(l)), cos(dtr(l)))) / 15.0
        ra = fixHour(ra)

        let eqt = q / 15.0 - ra
        let noon = fixHour(12.0 + tzOffset - longitude / 15.0 - eqt)

        // Sunrise & Sunset: 90.833°
        let sunZenith = 90.833
        let sunriseDiff = (1.0 / 15.0) * rtd(acos((-sin(dtr(sunZenith - 90.0)) - sin(dtr(latitude)) * sin(dtr(decl))) / (cos(dtr(latitude)) * cos(dtr(decl)))))
        let sunrise = noon - sunriseDiff
        let sunset = noon + sunriseDiff

        // Fajr (18°)
        let fajrDiff = (1.0 / 15.0) * rtd(acos((-sin(dtr(fajrAngle)) - sin(dtr(latitude)) * sin(dtr(decl))) / (cos(dtr(latitude)) * cos(dtr(decl)))))
        let fajr = noon - fajrDiff

        // Isha (18°)
        let ishaDiff = (1.0 / 15.0) * rtd(acos((-sin(dtr(ishaAngle)) - sin(dtr(latitude)) * sin(dtr(decl))) / (cos(dtr(latitude)) * cos(dtr(decl)))))
        let isha = noon + ishaDiff

        // Asr
        let altitude = rtd(atan(1.0 / (asrMethod.shadowFactor + tan(dtr(abs(latitude - decl))))))
        let cosT = (sin(dtr(altitude)) - sin(dtr(latitude)) * sin(dtr(decl))) / (cos(dtr(latitude)) * cos(dtr(decl)))
        let asrDiff = (1.0 / 15.0) * rtd(acos(cosT))
        let asr = noon + asrDiff

        // 1-minute safety buffer after true solar noon for Dhuhr
        let dhuhr = noon + (1.0 / 60.0)

        return (fajr, sunrise, dhuhr, asr, sunset, isha)
    }

    public func getCurrentWaqt(now: Date = Date(), dailyTimes: DailyPrayerTimes) -> WaqtState {
        if now < dailyTimes.fajr {
            let remaining = dailyTimes.fajr.timeIntervalSince(now)
            return WaqtState(
                activePrayer: .isha,
                nextPrayer: .fajr,
                targetDate: dailyTimes.fajr,
                remainingSeconds: remaining,
                totalSeconds: 28800,
                progress: 0.85,
                isBetweenSunriseAndDhuhr: false
            )
        } else if now >= dailyTimes.fajr && now < dailyTimes.sunrise {
            let total = dailyTimes.sunrise.timeIntervalSince(dailyTimes.fajr)
            let remaining = dailyTimes.sunrise.timeIntervalSince(now)
            let elapsed = now.timeIntervalSince(dailyTimes.fajr)
            return WaqtState(
                activePrayer: .fajr,
                nextPrayer: .dhuhr,
                targetDate: dailyTimes.sunrise,
                remainingSeconds: remaining,
                totalSeconds: total,
                progress: max(0, min(1, elapsed / max(total, 1))),
                isBetweenSunriseAndDhuhr: false
            )
        } else if now >= dailyTimes.sunrise && now < dailyTimes.dhuhr {
            let total = dailyTimes.dhuhr.timeIntervalSince(dailyTimes.sunrise)
            let remaining = dailyTimes.dhuhr.timeIntervalSince(now)
            let elapsed = now.timeIntervalSince(dailyTimes.sunrise)
            return WaqtState(
                activePrayer: nil,
                nextPrayer: .dhuhr,
                targetDate: dailyTimes.dhuhr,
                remainingSeconds: remaining,
                totalSeconds: total,
                progress: max(0, min(1, elapsed / max(total, 1))),
                isBetweenSunriseAndDhuhr: true
            )
        } else if now >= dailyTimes.dhuhr && now < dailyTimes.asr {
            let total = dailyTimes.asr.timeIntervalSince(dailyTimes.dhuhr)
            let remaining = dailyTimes.asr.timeIntervalSince(now)
            let elapsed = now.timeIntervalSince(dailyTimes.dhuhr)
            return WaqtState(
                activePrayer: .dhuhr,
                nextPrayer: .asr,
                targetDate: dailyTimes.asr,
                remainingSeconds: remaining,
                totalSeconds: total,
                progress: max(0, min(1, elapsed / max(total, 1))),
                isBetweenSunriseAndDhuhr: false
            )
        } else if now >= dailyTimes.asr && now < dailyTimes.maghrib {
            let total = dailyTimes.maghrib.timeIntervalSince(dailyTimes.asr)
            let remaining = dailyTimes.maghrib.timeIntervalSince(now)
            let elapsed = now.timeIntervalSince(dailyTimes.asr)
            return WaqtState(
                activePrayer: .asr,
                nextPrayer: .maghrib,
                targetDate: dailyTimes.maghrib,
                remainingSeconds: remaining,
                totalSeconds: total,
                progress: max(0, min(1, elapsed / max(total, 1))),
                isBetweenSunriseAndDhuhr: false
            )
        } else if now >= dailyTimes.maghrib && now < dailyTimes.isha {
            let total = dailyTimes.isha.timeIntervalSince(dailyTimes.maghrib)
            let remaining = dailyTimes.isha.timeIntervalSince(now)
            let elapsed = now.timeIntervalSince(dailyTimes.maghrib)
            return WaqtState(
                activePrayer: .maghrib,
                nextPrayer: .isha,
                targetDate: dailyTimes.isha,
                remainingSeconds: remaining,
                totalSeconds: total,
                progress: max(0, min(1, elapsed / max(total, 1))),
                isBetweenSunriseAndDhuhr: false
            )
        } else {
            let total = dailyTimes.nextFajr.timeIntervalSince(dailyTimes.isha)
            let remaining = dailyTimes.nextFajr.timeIntervalSince(now)
            let elapsed = now.timeIntervalSince(dailyTimes.isha)
            return WaqtState(
                activePrayer: .isha,
                nextPrayer: .fajr,
                targetDate: dailyTimes.nextFajr,
                remainingSeconds: max(0, remaining),
                totalSeconds: total,
                progress: max(0, min(1, elapsed / max(total, 1))),
                isBetweenSunriseAndDhuhr: false
            )
        }
    }
}
