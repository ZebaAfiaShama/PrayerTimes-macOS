import Foundation
import UserNotifications
import AppKit

public final class NotificationHelper: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationHelper()

    private var center: UNUserNotificationCenter?

    private override init() {
        super.init()
        // UNUserNotificationCenter requires a bundle identifier. If run outside a bundle, center is nil.
        if Bundle.main.bundleIdentifier != nil {
            let unc = UNUserNotificationCenter.current()
            unc.delegate = self
            self.center = unc
        }
    }

    public func requestAuthorization() {
        guard let center = center else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    public func sendNotification(title: String, subtitle: String? = nil, body: String, identifier: String = UUID().uuidString) {
        if let center = center {
            let content = UNMutableNotificationContent()
            content.title = title
            if let subtitle = subtitle {
                content.subtitle = subtitle
            }
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            center.add(request) { [weak self] error in
                if error != nil {
                    self?.sendAppleScriptNotification(title: title, subtitle: subtitle, body: body)
                }
            }
        } else {
            sendAppleScriptNotification(title: title, subtitle: subtitle, body: body)
        }
    }

    public func sendAppleScriptNotification(title: String, subtitle: String?, body: String) {
        var script = "display notification \"\(body.replacingOccurrences(of: "\"", with: "\\\""))\" with title \"\(title.replacingOccurrences(of: "\"", with: "\\\""))\""
        if let sub = subtitle {
            script += " subtitle \"\(sub.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        script += " sound name \"default\""

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
