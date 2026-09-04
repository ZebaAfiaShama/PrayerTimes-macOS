import SwiftUI

public struct PopoverView: View {
    @ObservedObject var store: PrayerStore = PrayerStore.shared
    @ObservedObject var locationMgr: LocationManager = LocationManager.shared
    @ObservedObject var launchHelper: LaunchAtLoginHelper = LaunchAtLoginHelper.shared
    @State private var showingSettings: Bool = false

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        f.timeZone = store.currentTimeZone
        return f
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeZone = store.currentTimeZone
        return f
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 14) {
                    // MARK: - Active Waqt Banner
                    heroWaqtView

                    // MARK: - Today's Prayers & Checkboxes
                    prayerScheduleCard

                    // MARK: - Kaza (Missed) Tracker
                    kazaTrackerCard

                    // MARK: - Settings Section (Collapsible)
                    if showingSettings {
                        settingsCard
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 520)

            Divider()

            // MARK: - Bottom Bar
            bottomBar
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            launchHelper.checkStatus()
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if let logoImg = NSImage(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AppLogo.png")) {
                        Image(nsImage: logoImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .cornerRadius(5)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    } else {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .bold))
                    }

                    Text("Prayer Times")
                        .font(.system(size: 15, weight: .bold))
                }
                Text("📍 \(store.cityName), \(store.countryName) • \(dateFormatter.string(from: store.currentDate))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingSettings.toggle()
                }
            }) {
                Image(systemName: showingSettings ? "gearshape.fill" : "gearshape")
                    .foregroundColor(showingSettings ? .blue : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Settings & Options")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Hero Waqt View
    private var heroWaqtView: some View {
        let state = store.waqtState
        return VStack(spacing: 8) {
            HStack {
                if let active = state.activePrayer {
                    HStack(spacing: 6) {
                        Image(systemName: active.iconName)
                            .foregroundColor(.green)
                        Text("\(active.rawValue) Waqt Active")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    }
                } else if state.isBetweenSunriseAndDhuhr {
                    HStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text("Ishraq / Chasht")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if let active = state.activePrayer {
                    Text("Ends at \(timeFormatter.string(from: store.dailyTimes.endTime(for: active)))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("Dhuhr at \(timeFormatter.string(from: store.dailyTimes.dhuhr))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // Big Countdown Timer
            HStack(alignment: .firstTextBaseline) {
                Text(state.countdownFormatted)
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(.primary)

                Text("remaining")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(1.0 - state.progress))), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
    }

    // MARK: - Prayer Schedule Card with Checkboxes
    private var prayerScheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Prayers")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("Check if completed")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 6) {
                // Fajr
                prayerRow(prayer: .fajr)

                // Sunrise indicator row
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sunrise.fill")
                            .foregroundColor(.orange.opacity(0.8))
                            .frame(width: 18)
                        Text("Sunrise (সূর্যোদয়)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(timeFormatter.string(from: store.dailyTimes.sunrise))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(6)

                // Dhuhr
                prayerRow(prayer: .dhuhr)

                // Asr
                prayerRow(prayer: .asr)

                // Maghrib
                prayerRow(prayer: .maghrib)

                // Isha
                prayerRow(prayer: .isha)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func prayerRow(prayer: PrayerType) -> some View {
        let startTime = store.dailyTimes.time(for: prayer)
        let endTime = store.dailyTimes.endTime(for: prayer)
        let isCompleted = store.completedToday[prayer] ?? false
        let isActive = (store.waqtState.activePrayer == prayer)
        let isPassed = Date() >= endTime

        return HStack(spacing: 8) {
            // Icon & Name
            HStack(spacing: 8) {
                Image(systemName: prayer.iconName)
                    .foregroundColor(isActive ? .green : (isCompleted ? .secondary : .primary))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(prayer.rawValue)
                            .font(.system(size: 12, weight: isActive ? .bold : .medium))
                        Text("(\(prayer.localizedBanglaName))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text("\(timeFormatter.string(from: startTime)) – \(timeFormatter.string(from: endTime))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Active Badge
            if isActive {
                Text("NOW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
            } else if isPassed && !isCompleted {
                Text("MISSED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(4)
            }

            // Checkbox
            Button(action: {
                store.togglePrayer(prayer)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isCompleted ? .green : .gray)
                    Text(isCompleted ? "Prayed" : "Pray")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isCompleted ? .green : .secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isCompleted ? Color.green.opacity(0.1) : Color.gray.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .help(isCompleted ? "Mark as not prayed" : "Mark as prayed today")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isActive ? Color.green.opacity(0.07) : Color.clear)
        .cornerRadius(6)
    }

    // MARK: - Kaza Tracker Card
    private var kazaTrackerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("Kaza (Qaza) Namaz Tracker")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                Spacer()

                if store.totalKaza > 0 {
                    Text("\(store.totalKaza) Missed")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(4)
                } else {
                    Text("All Caught Up! ✨")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
            }

            Text("Auto-increments when a waqt ends without being marked. Decrement when you pray a Kaza.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Grid of 5 prayers
            HStack(spacing: 6) {
                ForEach(PrayerType.allCases) { prayer in
                    let count = store.kazaCounts[prayer] ?? 0
                    VStack(spacing: 4) {
                        Text(prayer.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("\(count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(count > 0 ? .red : .primary)

                        HStack(spacing: 4) {
                            Button(action: {
                                store.decrementKaza(for: prayer)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(count > 0 ? .green : .gray.opacity(0.4))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(count <= 0)
                            .help("Mark one Kaza \(prayer.rawValue) completed")

                            Button(action: {
                                store.incrementKaza(for: prayer)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Add one missed \(prayer.rawValue)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(count > 0 ? Color.red.opacity(0.05) : Color.gray.opacity(0.05))
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - Settings Card
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preferences")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            // Launch at Startup
            HStack {
                Text("Launch at Mac Startup:")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { launchHelper.isEnabled },
                    set: { launchHelper.setEnabled($0) }
                ))
                .toggleStyle(SwitchToggleStyle())
            }

            Divider()

            // Location Mode
            VStack(alignment: .leading, spacing: 6) {
                Text("Location Detection:")
                    .font(.system(size: 11, weight: .medium))
                
                HStack(spacing: 8) {
                    Toggle("Auto-Detect Location (GPS)", isOn: $locationMgr.isAutoLocationEnabled)
                        .font(.system(size: 11))
                        .toggleStyle(SwitchToggleStyle())

                    Spacer()

                    if locationMgr.isAutoLocationEnabled {
                        Button("Refresh") {
                            locationMgr.requestLocation()
                        }
                        .buttonStyle(DefaultButtonStyle())
                        .font(.system(size: 10))
                    } else {
                        Button("Reset to Dhaka") {
                            locationMgr.setManualDhaka()
                        }
                        .buttonStyle(DefaultButtonStyle())
                        .font(.system(size: 10))
                    }
                }

                Text(locationMgr.isAutoLocationEnabled ? "Active: \(store.cityName) (lat \(String(format: "%.2f", store.latitude)), lon \(String(format: "%.2f", store.longitude)))" : "Manual: Dhaka, Bangladesh")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Asr School
            VStack(alignment: .leading, spacing: 4) {
                Text("Asr Juristic Method:")
                    .font(.system(size: 11, weight: .medium))
                Picker("", selection: $store.asrMethod) {
                    ForEach(AsrMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // Menu Bar Icon Style
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu Bar Icon:")
                    .font(.system(size: 11, weight: .medium))
                Picker("", selection: $store.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // Menu Bar Display Mode
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu Bar Text:")
                    .font(.system(size: 11, weight: .medium))
                Picker("", selection: $store.menuBarMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(PopUpButtonPickerStyle())
            }

            // Test Notifications
            VStack(alignment: .leading, spacing: 4) {
                Text("Notification Testing:")
                    .font(.system(size: 11, weight: .medium))
                HStack(spacing: 8) {
                    Button("Test Waqt Alert") {
                        store.triggerTestStartNotification()
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .font(.system(size: 10))

                    Button("Test Missed Alert") {
                        store.triggerTestMissedNotification()
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .font(.system(size: 10))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            Text("📍 \(store.cityName) (\(String(format: "%.2f°", store.latitude)), \(String(format: "%.2f°", store.longitude))) • \(store.currentTimeZone.abbreviation() ?? "")")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(BorderlessButtonStyle())
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
