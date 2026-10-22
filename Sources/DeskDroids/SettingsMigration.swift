import Foundation

/// The dev build (`.build/debug/DeskDroids`) keeps its settings in the `DeskDroids` defaults domain;
/// the `.app` keeps them under its bundle id. This carries them over so the app starts where the
/// dev build left off.
enum SettingsMigration {
    private static let legacyDomain = "DeskDroids"
    private static let keys = [Voice.modeKey, StatusBarController.catModeKey]

    /// Call before anything reads the settings.
    static func runIfNeeded() {
        guard Bundle.main.isApp, let legacy = UserDefaults(suiteName: legacyDomain) else { return }
        migrate(from: legacy, to: .standard)
    }

    static func migrate(from legacy: UserDefaults, to new: UserDefaults) {
        for key in keys where new.object(forKey: key) == nil {
            if let value = legacy.object(forKey: key) {
                new.set(value, forKey: key)
            }
        }
    }
}
