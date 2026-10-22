import AppKit
import ServiceManagement

/// "Open at login" via `SMAppService.mainApp`. Only the `.app` can be a login item; the dev build has
/// no bundle to register.
enum LoginItem {
    static var isAvailable: Bool { Bundle.main.isApp }

    static var menuState: NSControl.StateValue {
        guard isAvailable else { return .off }
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .mixed
        default: return .off
        }
    }

    static func toggle() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled: try service.unregister()
            case .requiresApproval: break  // already registered; it just needs the user's OK
            default: try service.register()
            }
        } catch {
            NSLog("desk-droids: open at login failed: \(error)")
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
}

extension Bundle {
    /// True for `DeskDroids.app`, false for the bare `.build/debug/DeskDroids` binary.
    var isApp: Bool { bundleIdentifier != nil }
}
