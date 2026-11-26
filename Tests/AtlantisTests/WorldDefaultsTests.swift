import AppKit
import XCTest
@testable import Atlantis

final class WorldDefaultsTests: XCTestCase {
    @MainActor
    func testGlobalEditorKeepsSharedTabsInTheirOriginalOrder() throws {
        let pane = WorldDefaults()
        let view = try XCTUnwrap(pane.preferencePaneView() as? NSTabView)
        XCTAssertEqual(view.tabViewItems.map(\.label), ["Formatting", "Highlights", "Spawns", "Events", "Aliases", "User Variables"])
        XCTAssertEqual(view.frame.size, NSSize(width: 900, height: 700))
        view.selectTabViewItem(at: 1)
        XCTAssertTrue(view === pane.preferencePaneView())
        XCTAssertEqual(view.selectedTabViewItem?.label, "Highlights")
    }

    @MainActor
    func testFormattingDefaultsRestoreInheritedColorsAndLockControlsWithoutDimming() throws {
        let preferences = RDAtlantisWorldPreferences()
        let character = "Test Character"
        preferences.addCharacter(character)
        let ansiKey = "atlantis.colors.ansi"
        let boldKey = "atlantis.formatting.boldIntense"
        let colorKeys = ["url", "system", "background", "default", "selection"].map { "atlantis.colors." + $0 }

        preferences.setPreference(Array(repeating: NSColor.blue, count: 16), forKey: ansiKey, withCharacter: nil)
        preferences.setPreference(Array(repeating: NSColor.red, count: 16), forKey: ansiKey, withCharacter: character)
        preferences.setPreference(true, forKey: boldKey, withCharacter: nil)
        preferences.setPreference(false, forKey: boldKey, withCharacter: character)
        for key in colorKeys {
            preferences.setPreference(NSColor.blue, forKey: key, withCharacter: nil)
            preferences.setPreference(NSColor.red, forKey: key, withCharacter: character)
        }

        let editor = try XCTUnwrap(WorldFormattingEditor(world: preferences, forCharacter: character))
        let view = try XCTUnwrap(editor.configTabView())
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        defer { window.close() }

        let controls = descendants(of: view)
        let wells = controls.compactMap { $0 as? NSColorWell }
        let buttons = controls.compactMap { $0 as? NSButton }
        let useDefaults = try XCTUnwrap(buttons.first { $0.title == "Use defaults" })
        let bolding = try XCTUnwrap(buttons.first { $0.title == "Display intense colors bolded" })
        let firstWell = try XCTUnwrap(wells.first)

        XCTAssertEqual(wells.count, 21)
        XCTAssertEqual(useDefaults.state, .off)
        XCTAssertEqual(bolding.state, .off)
        XCTAssertTrue(wells.allSatisfy { $0.color == .red })
        firstWell.activate(false)
        XCTAssertTrue(firstWell.isActive)

        useDefaults.performClick(nil)

        XCTAssertEqual(useDefaults.state, .on)
        XCTAssertEqual(bolding.state, .on)
        XCTAssertFalse(firstWell.isActive)
        for control in wells as [NSControl] + [bolding] {
            XCTAssertTrue(control.isEnabled)
            XCTAssertEqual(control.alphaValue, 1)
            XCTAssertFalse(control.acceptsFirstResponder)
            XCTAssertNotNil(control.hitTest(NSPoint(x: control.frame.midX, y: control.frame.midY)))
            control.performClick(nil)
        }
        XCTAssertFalse(firstWell.isActive)
        XCTAssertEqual(bolding.state, .on)
        XCTAssertTrue(wells.allSatisfy { $0.color == .blue })
        for key in [ansiKey, boldKey] + colorKeys {
            XCTAssertNil(preferences.preference(forKey: key, withCharacter: character, fallback: false))
        }

        XCTAssertNil(editor.value(forKey: "rdColorMappingHint"))
        for control in [firstWell, bolding] as [NSControl] {
            XCTAssertNil(control.toolTip)
            let click = try XCTUnwrap(NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: control.convert(NSPoint(x: control.bounds.midX, y: control.bounds.midY), to: nil),
                modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            window.sendEvent(click)
            let hint = try XCTUnwrap(editor.value(forKey: "rdColorMappingHint") as? NSPopover)
            XCTAssertTrue(hint.isShown)
            XCTAssertEqual(hint.positioningRect, control.bounds)
            XCTAssertTrue(descendants(of: try XCTUnwrap(hint.contentViewController?.view))
                .compactMap { $0 as? NSTextField }
                .contains { $0.stringValue == "Uncheck Use defaults to configure a custom color mapping." })
            XCTAssertFalse(firstWell.isActive)
            XCTAssertEqual(bolding.state, .on)
            if control === firstWell {
                let deadline = Date().addingTimeInterval(7)
                while hint.isShown && Date() < deadline {
                    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                }
                XCTAssertFalse(hint.isShown, "The hint should dismiss itself after five seconds")
            }
        }

        useDefaults.performClick(nil)

        XCTAssertEqual(useDefaults.state, .off)
        XCTAssertFalse((editor.value(forKey: "rdColorMappingHint") as? NSPopover)?.isShown ?? true)
        XCTAssertNotNil(firstWell.hitTest(NSPoint(x: firstWell.frame.midX, y: firstWell.frame.midY)))
        firstWell.activate(false)
        XCTAssertTrue(firstWell.isActive)
        firstWell.deactivate()
        bolding.performClick(nil)
        XCTAssertEqual(bolding.state, .off)
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    @MainActor
    func testPaneCommitsTheEditorAndReusesItsNativeView() {
        let editor = RecordingWorldEditor(view: NSTabView(frame: .zero))
        let pane = WorldDefaults(editor: editor)
        XCTAssertTrue(pane.preferencePaneView() === editor.view)
        XCTAssertEqual(editor.commits, 0)
        pane.preferencePaneCommit()
        XCTAssertEqual(editor.commits, 1)
    }
}

private final class RecordingWorldEditor: WorldConfigurationEditor {
    let view: NSView
    var commits = 0

    init(view: NSView) {
        self.view = view
        super.init()
    }

    override func configView() -> NSView! { view }
    override func commitAll() { commits += 1 }
}
