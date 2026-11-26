import AppKit
import SwiftUI
import XCTest
@testable import Atlantis

final class GeneralPreferencesTests: XCTestCase {
    @MainActor
    func testInvertedOptionsDefaultToEnabledAndPersistOptOut() {
        withSettings { settings in
            for option in [GeneralPreferences.Option.checkOnStartup, .clearInput, .javaScript] {
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
    func testSectionsKeepTheirSpacingWhenWindowBecomesTooShort() throws {
        try withSettings { settings in
            var frames: [String: CGRect] = [:]
            let host = NSHostingView(rootView: GeneralPreferencesForm(settings: settings) { title, frame in
                frames[title] = frame
            })
            host.sizingOptions = []
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 433, height: 640),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFront(nil)
            defer { window.close() }

            let titles = ["Global UI Options", "Global Window Options", "Startup Options", "Experimental"]
            func layout(at height: CGFloat) throws -> [CGRect] {
                window.setContentSize(CGSize(width: 433, height: height))
                host.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                XCTAssertEqual(host.bounds.height, height, accuracy: 1)
                return try titles.map { try XCTUnwrap(frames[$0], $0) }
            }

            let tall = try layout(at: 640)
            let short = try layout(at: 140)
            for sections in [tall, short] {
                for (upper, lower) in zip(sections, sections.dropFirst()) {
                    XCTAssertEqual(lower.minY - upper.maxY, 8, accuracy: 1)
                }
            }
            for (before, after) in zip(tall, short) {
                XCTAssertGreaterThan(before.height, 0)
                XCTAssertEqual(before.height, after.height, accuracy: 1)
            }
            XCTAssertEqual(short[0].minY, tall[0].minY, accuracy: 1)
            XCTAssertGreaterThan(try XCTUnwrap(short.last).maxY, host.bounds.height)

            func scrollView(in view: NSView) -> NSScrollView? {
                (view as? NSScrollView) ?? view.subviews.lazy.compactMap { scrollView(in: $0) }.first
            }

            let scroll = try XCTUnwrap(scrollView(in: host))
            let document = try XCTUnwrap(scroll.documentView)
            let viewport = scroll.contentView
            XCTAssertGreaterThan(document.bounds.height, viewport.bounds.height)
            var bottom = viewport.bounds.origin
            bottom.y = document.isFlipped ? document.bounds.maxY - viewport.bounds.height : document.bounds.minY
            viewport.scroll(to: bottom)
            scroll.reflectScrolledClipView(viewport)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            let experimental = try XCTUnwrap(frames["Experimental"])
            XCTAssertGreaterThanOrEqual(experimental.minY, 0)
            XCTAssertLessThanOrEqual(experimental.maxY, host.bounds.height)
        }
    }

    @MainActor
    private func withSettings(
        shortcutChanged: @escaping (Bool) -> Void = { _ in },
        refreshBadge: @escaping () -> Void = {},
        _ body: (GeneralPreferences.Settings) throws -> Void
    ) rethrows {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(GeneralPreferences.Settings(defaults: defaults, shortcutChanged: shortcutChanged, refreshBadge: refreshBadge))
    }
}
