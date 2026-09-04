import AppKit
import SwiftUI
import UserNotifications
import CoreLocation

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var timer: Timer?

    public static func createMosqueTemplateIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()

            // 1. Minarets
            let leftMinaret = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 2.2, height: 10.5), xRadius: 0.5, yRadius: 0.5)
            leftMinaret.fill()

            let leftFinial = NSBezierPath(ovalIn: NSRect(x: 1.6, y: 12.8, width: 2.0, height: 2.0))
            leftFinial.fill()

            let rightMinaret = NSBezierPath(roundedRect: NSRect(x: 14.3, y: 1.5, width: 2.2, height: 10.5), xRadius: 0.5, yRadius: 0.5)
            rightMinaret.fill()

            let rightFinial = NSBezierPath(ovalIn: NSRect(x: 14.4, y: 12.8, width: 2.0, height: 2.0))
            rightFinial.fill()

            // 2. Base building
            let base = NSBezierPath(rect: NSRect(x: 3.5, y: 1.5, width: 11.0, height: 6.5))
            base.fill()

            // 3. Central Onion Dome
            let dome = NSBezierPath()
            dome.move(to: NSPoint(x: 4.2, y: 8.0))
            dome.curve(to: NSPoint(x: 9.0, y: 14.5),
                       controlPoint1: NSPoint(x: 4.2, y: 11.5),
                       controlPoint2: NSPoint(x: 7.2, y: 13.8))
            dome.curve(to: NSPoint(x: 13.8, y: 8.0),
                       controlPoint1: NSPoint(x: 10.8, y: 13.8),
                       controlPoint2: NSPoint(x: 13.8, y: 11.5))
            dome.close()
            dome.fill()

            // 4. Dome crescent spire
            let spire = NSBezierPath(rect: NSRect(x: 8.5, y: 14.5, width: 1.0, height: 2.2))
            spire.fill()

            // 5. Arched Doorway (Cutout)
            let door = NSBezierPath()
            door.move(to: NSPoint(x: 7.3, y: 1.5))
            door.line(to: NSPoint(x: 7.3, y: 4.6))
            door.curve(to: NSPoint(x: 10.7, y: 4.6),
                       controlPoint1: NSPoint(x: 7.3, y: 6.2),
                       controlPoint2: NSPoint(x: 10.7, y: 6.2))
            door.line(to: NSPoint(x: 10.7, y: 1.5))
            door.close()

            NSGraphicsContext.current?.compositingOperation = .clear
            door.fill()

            return true
        }
        img.isTemplate = true
        return img
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory (menu bar item only, no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Request Notification Permission
        NotificationHelper.shared.requestAuthorization()

        // Request Location Permission & Start GPS Auto-detection
        LocationManager.shared.requestAuthorizationAndLocation()

        // Create Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView())
        self.popover = popover

        // Create Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = AppDelegate.createMosqueTemplateIcon()
            button.imagePosition = .imageLeft
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Setup 1-second update timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateState()
        }
        RunLoop.main.add(timer!, forMode: .common)

        updateState()
    }

    private func updateState() {
        PrayerStore.shared.tick()
        updateMenuBarButton()
    }

    private func updateMenuBarButton() {
        guard let button = statusItem.button else { return }

        let store = PrayerStore.shared
        let state = store.waqtState
        let mode = store.menuBarMode
        let iconStyle = store.menuBarIconStyle

        // Configure Icon
        switch iconStyle {
        case .mosqueVector:
            button.image = AppDelegate.createMosqueTemplateIcon()
        case .dynamicWaqt:
            if let active = state.activePrayer {
                button.image = NSImage(systemSymbolName: active.iconName, accessibilityDescription: active.rawValue)
            } else {
                button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Ishraq / Chasht")
            }
        case .appColorLogo:
            let logoUrl = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/MenuBarIcon.png")
            if let customIcon = NSImage(contentsOf: logoUrl) {
                customIcon.size = NSSize(width: 18, height: 18)
                button.image = customIcon
            } else {
                button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Prayer Times")
            }
        }

        // Configure Text Title
        switch mode {
        case .countdownAndIcon:
            if let active = state.activePrayer {
                button.title = " \(active.rawValue): \(state.shortRemainingText)"
            } else {
                button.title = " Dhuhr in \(state.shortRemainingText)"
            }
        case .prayerAndIcon:
            if let active = state.activePrayer {
                button.title = " \(active.rawValue)"
            } else {
                button.title = " Ishraq"
            }
        case .iconOnly:
            button.title = ""
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            PrayerStore.shared.refreshTimes()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
}
