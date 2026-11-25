import XCTest
@testable import Atlantis

final class WindowingPreferencesTests: XCTestCase {
    @MainActor
    func testWindowGroupingAndStyleUseExistingValues() {
        var chosenStyles: [WindowingPreferences.Style] = []
        withSettings(changeStyle: { chosenStyles.append($0) }) { settings in
            XCTAssertEqual(settings.grouping, .automatic)
            XCTAssertEqual(settings.style, .source)
            for (group, stored) in zip(WindowingPreferences.Grouping.allCases, ["default", "contained", "scattered"]) {
                settings.grouping = group
                XCTAssertEqual(settings.defaults.string(forKey: "lemuria.window.behavior"), stored)
            }
            for (style, stored) in zip(WindowingPreferences.Style.allCases, ["source", "tabbed", "outline"]) {
                settings.style = style
                XCTAssertEqual(settings.defaults.string(forKey: "lemuria.display.style"), stored)
            }
            XCTAssertEqual(chosenStyles, [.source, .tabbed, .outline])
        }
    }

    @MainActor
    func testDragInversionAndStatusBarVisibilityNotification() {
        var notifications = 0
        withSettings(changeStatusVisibility: { notifications += 1 }) { settings in
            XCTAssertTrue(settings.drag)
            settings.drag = false
            XCTAssertTrue(settings.defaults.bool(forKey: "lemuria.dragging.disabled"))
            settings.hideStatus = true
            XCTAssertTrue(settings.defaults.bool(forKey: "atlantis.statusbar.kill"))
            XCTAssertEqual(notifications, 1)
        }
    }

    @MainActor
    func testSmallIconsAndStatusPositionRefreshImmediately() {
        var iconUpdates = 0
        var statusPositions: [Bool] = []
        withSettings(syncDisplay: { iconUpdates += 1 }, changeStatusPosition: { statusPositions.append($0) }) { settings in
            settings.smallIcons = true
            settings.bottomStatus = true
            settings.bottomStatus = false
            XCTAssertEqual(iconUpdates, 1)
            XCTAssertTrue(settings.defaults.bool(forKey: "lemuria.display.smallicons"))
            XCTAssertEqual(statusPositions, [true, false])
            XCTAssertFalse(settings.defaults.bool(forKey: "atlantis.statusbar.bottom"))
        }
    }

    @MainActor
    private func withSettings(
        changeStyle: @escaping (WindowingPreferences.Style) -> Void = { _ in },
        syncDisplay: @escaping () -> Void = {},
        changeStatusPosition: @escaping (Bool) -> Void = { _ in },
        changeStatusVisibility: @escaping () -> Void = {},
        _ body: (WindowingPreferences.Settings) -> Void
    ) {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(WindowingPreferences.Settings(
            defaults: defaults,
            changeStyle: changeStyle,
            syncDisplay: syncDisplay,
            changeStatusPosition: changeStatusPosition,
            changeStatusVisibility: changeStatusVisibility
        ))
    }
}
