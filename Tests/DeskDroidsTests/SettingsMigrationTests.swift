import XCTest
@testable import DeskDroids

final class SettingsMigrationTests: XCTestCase {
    private var legacy: UserDefaults!
    private var new: UserDefaults!

    override func setUp() {
        legacy = scratch("legacy")
        new = scratch("new")
    }

    private func scratch(_ name: String) -> UserDefaults {
        let suite = "desk-droids-tests.\(name)"
        UserDefaults().removePersistentDomain(forName: suite)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }

    func testCopiesTheDevBuildsSoundAndCatSettings() {
        legacy.set("muted", forKey: "soundMode")
        legacy.set("always", forKey: "catMode")

        SettingsMigration.migrate(from: legacy, to: new)

        XCTAssertEqual(new.string(forKey: "soundMode"), "muted")
        XCTAssertEqual(new.string(forKey: "catMode"), "always")
    }

    func testKeepsSettingsTheAppAlreadyHas() {
        legacy.set("muted", forKey: "soundMode")
        legacy.set("always", forKey: "catMode")
        new.set("importantOnly", forKey: "soundMode")

        SettingsMigration.migrate(from: legacy, to: new)

        XCTAssertEqual(new.string(forKey: "soundMode"), "importantOnly")
        XCTAssertEqual(new.string(forKey: "catMode"), "always")
    }
}
