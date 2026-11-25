import AppKit
import XCTest
@testable import Atlantis

final class GeneralPreferencesTests: XCTestCase {
    @MainActor
    func testStartupAndClearInputUseInvertedDefaults() {
        withSettings { settings in
            for option in [GeneralPreferences.Option.checkOnStartup, .clearInput] {
                XCTAssertTrue(settings.enabled(option))
                settings.setEnabled(false, for: option)
                XCTAssertTrue(settings.defaults.bool(forKey: option.rawValue))
                XCTAssertFalse(settings.enabled(option))
            }
        }
    }

    @MainActor
    func testURLLengthReloadAndEditing() {
        withSettings { settings in
            XCTAssertEqual(settings.urlLength, "60")
            XCTAssertFalse(settings.enabled(.shrinkURLs))
            settings.urlLength = "75"
            settings.setEnabled(true, for: .shrinkURLs)
            XCTAssertEqual(settings.defaults.integer(forKey: "atlantis.input.urlMaxLen"), 75)
            settings.urlLength = "101"
            XCTAssertEqual(settings.defaults.integer(forKey: "atlantis.input.urlMaxLen"), 75)
            settings.saveURLLength()
            settings.setEnabled(false, for: .shrinkURLs)
            settings.reload()
            XCTAssertEqual(settings.urlLength, "101")
        }
    }

    @MainActor
    func testChoicesPersistAndLiveCallbacksRun() {
        var shortcutChanges: [Bool] = []
        var badgeRefreshes = 0
        withSettings(shortcutChanged: { shortcutChanges.append($0) }, refreshBadge: { badgeRefreshes += 1 }) { settings in
            settings.beep = 2
            XCTAssertEqual(settings.defaults.integer(forKey: "atlantis.beeptype"), 2)
            settings.setEnabled(true, for: .shortcut)
            settings.setEnabled(true, for: .badgeInactive)
            settings.setEnabled(true, for: .badgeHidden)
            XCTAssertEqual(shortcutChanges, [true])
            XCTAssertEqual(badgeRefreshes, 2)
            XCTAssertTrue(settings.defaults.bool(forKey: "atlantis.badge.inactive"))
            XCTAssertTrue(settings.defaults.bool(forKey: "atlantis.badge.hidden"))
        }
    }

    @MainActor
    private func withSettings(
        shortcutChanged: @escaping (Bool) -> Void = { _ in },
        refreshBadge: @escaping () -> Void = {},
        _ body: (GeneralPreferences.Settings) -> Void
    ) {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(GeneralPreferences.Settings(defaults: defaults, shortcutChanged: shortcutChanged, refreshBadge: refreshBadge))
    }
}
