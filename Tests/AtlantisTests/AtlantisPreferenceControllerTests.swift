import AppKit
import XCTest
@testable import Atlantis

final class AtlantisPreferenceControllerTests: XCTestCase {
    @MainActor
    func testSelectionCommitsAndReopening() throws {
        try withPreferences { controller, first, second in
            XCTAssertEqual(NSStringFromClass(type(of: controller)), "AtlantisPreferenceController")
            for selector in ["init", "addPane:", "showPreferences", "changeFont:"] {
                XCTAssertTrue(controller.responds(to: NSSelectorFromString(selector)))
            }

            let window = try XCTUnwrap(controller.window)
            let items = try XCTUnwrap(window.toolbar?.items)
            XCTAssertEqual(items.map(\.label), ["First", "Second"])
            XCTAssertEqual(window.title, "First")
            XCTAssertEqual(first.viewRequests, 1)
            XCTAssertEqual(second.viewRequests, 0)
            XCTAssertEqual(window.frameAutosaveName, AtlantisPreferenceController.frameAutosaveName)

            let initialFrame = window.frame
            click(items[1])
            XCTAssertEqual(window.title, "Second")
            XCTAssertEqual(first.commits, 0)
            XCTAssertEqual(second.viewRequests, 1)
            XCTAssertEqual(window.frame, initialFrame)

            click(items[0])
            XCTAssertEqual(second.commits, 1)
            XCTAssertEqual(first.viewRequests, 2)

            window.close()
            XCTAssertEqual(first.commits, 1)
            XCTAssertEqual(second.commits, 2)
            controller.showPreferences()
            XCTAssertTrue(controller.window === window)
            XCTAssertEqual(window.title, "First")
            XCTAssertEqual(first.viewRequests, 2)
        }
    }

    @MainActor
    func testResizedWindowKeepsItsFrameAcrossPaneSwitchesAndReopening() throws {
        try withPreferences { controller, _, _ in
            let window = try XCTUnwrap(controller.window)
            let items = try XCTUnwrap(window.toolbar?.items)
            window.setContentSize(NSSize(width: 610, height: 360))
            let resizedFrame = window.frame

            click(items[1])
            XCTAssertEqual(window.frame, resizedFrame)
            click(items[0])
            XCTAssertEqual(window.frame, resizedFrame)
            window.close()
            controller.showPreferences()
            XCTAssertEqual(window.frame, resizedFrame)

            window.saveFrame(usingName: AtlantisPreferenceController.frameAutosaveName)
            window.close()
            window.setFrameAutosaveName("")
            let nextController = AtlantisPreferenceController()
            nextController.add(SpyPane(name: "First", view: NSView()))
            nextController.showPreferences()
            let restoredWindow = try XCTUnwrap(nextController.window)
            defer {
                restoredWindow.close()
                restoredWindow.setFrameAutosaveName("")
            }
            XCTAssertEqual(restoredWindow.contentView?.bounds.size, NSSize(width: 610, height: 360))
        }
    }

    @MainActor
    func testFontActionReachesActivePaneAndSelectedTab() throws {
        let direct = FontView(frame: NSRect(x: 0, y: 0, width: 410, height: 200))
        let tabs = NSTabView(frame: NSRect(x: 0, y: 0, width: 580, height: 270))
        let firstTab = NSTabViewItem(identifier: "first")
        firstTab.view = FontView()
        let secondTab = NSTabViewItem(identifier: "second")
        let selected = FontView()
        secondTab.view = selected
        tabs.addTabViewItem(firstTab)
        tabs.addTabViewItem(secondTab)
        tabs.selectTabViewItem(secondTab)

        try withPreferences(firstView: direct, secondView: tabs) { controller, _, _ in
            let action = NSSelectorFromString("changeFont:")
            let sender = NSObject()
            _ = controller.perform(action, with: sender)
            XCTAssertTrue(direct.sender === sender)
            let items = try XCTUnwrap(controller.window?.toolbar?.items)
            click(items[1])
            _ = controller.perform(action, with: sender)
            XCTAssertTrue(selected.sender === sender)
            XCTAssertNil((firstTab.view as? FontView)?.sender)
        }
    }

    @MainActor
    func testHostsAllPreferencePanes() throws {
        XCTAssertTrue(RDPreferenceMainController() === NSApp.delegate)
        let panes = [
            GeneralPreferences(),
            NetworkPreferences(),
            WorldDefaults(),
            HotkeyPreferences(for: HotkeyCollection()),
            ToolbarEventPreferences(forEvents: ToolbarCollection()),
            WindowingPreferences()
        ] as [AtlantisPreferencePane]
        defer { withExtendedLifetime(panes) {} }
        // Host the real views with spy commits so the test does not save user data.
        let fixtures = try panes.map { pane in
            let view = try XCTUnwrap(pane.preferencePaneView())
            let name = try XCTUnwrap(pane.preferencePaneName())
            return SpyPane(name: name, view: view, image: pane.preferencePaneImage())
        }

        let worldDefaultsSize = fixtures[2].view.frame.size
        try withPreferences(panes: fixtures) { controller in
            let window = try XCTUnwrap(controller.window)
            let items = try XCTUnwrap(window.toolbar?.items)
            XCTAssertEqual(items.map(\.label), ["General", "Networking", "World Defaults", "Hotkeys", "Toolbar Events", "Windowing"])

            XCTAssertEqual(window.contentView?.bounds.size, worldDefaultsSize)
            let initialFrame = window.frame
            for (index, item) in items.enumerated() {
                click(item)
                let pane = fixtures[index]
                let host = try XCTUnwrap(window.contentView)
                XCTAssertFalse(pane.view === host, pane.name)
                XCTAssertTrue(pane.view.window === window, pane.name)
                XCTAssertTrue(pane.view.isDescendant(of: host), pane.name)
                XCTAssertFalse(pane.view.subviews.isEmpty, pane.name)
                XCTAssertEqual(window.frame, initialFrame, pane.name)
                XCTAssertEqual(pane.view.frame.size, host.bounds.size, pane.name)
            }
        }
    }

    @MainActor
    func testHostedFieldKeepsFocusAndValueWhileResizing() throws {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 410, height: 200))
        let field = NSTextField(frame: NSRect(x: 20, y: 20, width: 180, height: 24))
        field.stringValue = "Draft"
        content.addSubview(field)

        try withPreferences(firstView: content) { controller, first, _ in
            let window = try XCTUnwrap(controller.window)
            XCTAssertTrue(field.window === window)
            XCTAssertTrue(window.makeFirstResponder(field))
            let editor = try XCTUnwrap(field.currentEditor())
            editor.selectedRange = NSRange(location: 1, length: 2)
            var frame = window.frame
            frame.size.width += 25
            window.setFrame(frame, display: true)
            window.contentView?.layoutSubtreeIfNeeded()
            XCTAssertEqual(content.frame.width, frame.width, accuracy: 1)
            XCTAssertTrue(field.currentEditor() === editor)
            XCTAssertEqual(editor.selectedRange, NSRange(location: 1, length: 2))
            XCTAssertEqual(first.commits, 0)
        }
    }

    @MainActor
    private func withPreferences(
        firstView: NSView? = nil,
        secondView: NSView? = nil,
        _ body: (AtlantisPreferenceController, SpyPane, SpyPane) throws -> Void
    ) rethrows {
        let first = SpyPane(name: "First", view: firstView ?? NSView(frame: NSRect(x: 0, y: 0, width: 410, height: 200)))
        let second = SpyPane(name: "Second", view: secondView ?? NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 270)))
        try withPreferences(panes: [first, second]) { controller in
            try body(controller, first, second)
        }
    }

    @MainActor
    private func withPreferences(
        panes: [AtlantisPreferencePane],
        _ body: (AtlantisPreferenceController) throws -> Void
    ) rethrows {
        let defaults = UserDefaults.standard
        let frameKey = "NSWindow Frame " + AtlantisPreferenceController.frameAutosaveName
        let savedFrame = defaults.object(forKey: frameKey)
        defaults.removeObject(forKey: frameKey)
        defer { defaults.set(savedFrame, forKey: frameKey) }

        let controller = AtlantisPreferenceController()
        for pane in panes {
            controller.add(pane)
        }
        controller.showPreferences()
        defer {
            controller.window?.close()
            controller.window?.setFrameAutosaveName("")
        }
        try body(controller)
    }

    @MainActor
    private func click(_ item: NSToolbarItem) {
        guard let action = item.action else {
            XCTFail("Missing toolbar action")
            return
        }
        XCTAssertTrue(NSApp.sendAction(action, to: item.target, from: item))
    }
}

private final class SpyPane: NSObject, AtlantisPreferencePane {
    let name: String
    let view: NSView
    let image: NSImage?
    var commits = 0
    var viewRequests = 0

    init(name: String, view: NSView, image: NSImage? = nil) {
        self.name = name
        self.view = view
        self.image = image
    }

    func preferencePaneName() -> String! { name }
    func preferencePaneImage() -> NSImage! { image }
    func preferencePaneView() -> NSView! {
        viewRequests += 1
        return view
    }
    func preferencePaneCommit() { commits += 1 }
}

private final class FontView: NSView {
    var sender: NSObject?

    @objc func changeFont(_ sender: NSObject?) {
        self.sender = sender
    }
}
