import Foundation
import ServiceManagement
import Combine

public final class LaunchAtLoginHelper: ObservableObject {
    public static let shared = LaunchAtLoginHelper()

    @Published public var isEnabled: Bool = false

    private init() {
        checkStatus()
    }

    public func checkStatus() {
        if #available(macOS 13.0, *) {
            self.isEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }

    public func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                DispatchQueue.main.async {
                    self.isEnabled = (SMAppService.mainApp.status == .enabled)
                }
            } catch {
                print("SMAppService toggle notice: \(error.localizedDescription)")
            }
        }
    }
}
