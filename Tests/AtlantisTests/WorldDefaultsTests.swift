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
    func testSpawnOutlineClickReportsTheHitItemAndColumn() throws {
        let pane = WorldDefaults()
        let tabs = try XCTUnwrap(pane.preferencePaneView() as? NSTabView)
        let spawnTab = try XCTUnwrap(tabs.tabViewItems.first { $0.label == "Spawns" })
        tabs.selectTabViewItem(spawnTab)
        let content = try XCTUnwrap(spawnTab.view)
        let outline = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSOutlineView }.first)
        let window = NSWindow(contentRect: tabs.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = tabs
        window.orderFront(nil)
        defer {
            window.close()
            withExtendedLifetime(pane) {}
        }

        let expectedItem = try XCTUnwrap(outline.item(atRow: 0) as AnyObject?)
        let expectedColumn = try XCTUnwrap(outline.tableColumns.first)
        let oldDelegate = outline.delegate
        let delegate = OutlineClickDelegate()
        outline.delegate = delegate
        defer { outline.delegate = oldDelegate }

        let cell = outline.frameOfCell(atColumn: 0, row: 0)
        let point = NSPoint(x: cell.midX, y: cell.midY)
        XCTAssertEqual(outline.row(at: point), 0)
        XCTAssertEqual(outline.column(at: point), 0)
        let location = outline.convert(point, to: nil)
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: location, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        ))
        let up = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseUp, location: location, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 0
        ))
        NSApp.postEvent(up, atStart: true)
        defer {
            if NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast, inMode: .eventTracking, dequeue: false) === up {
                _ = NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast, inMode: .eventTracking, dequeue: true)
            }
        }
        _ = try XCTUnwrap(NSApp.nextEvent(
            matching: .leftMouseUp, until: .distantPast, inMode: .eventTracking, dequeue: false
        ))
        outline.mouseDown(with: down)

        XCTAssertTrue(delegate.item === expectedItem)
        XCTAssertTrue(delegate.column === expectedColumn)
    }

    @MainActor
    func testSpawnOutlineKeepsTheAddedSpawnSelectedAfterRename() throws {
        try withSpawnEditor { window, outline, content in
            let root = try XCTUnwrap(outline.item(atRow: 0) as AnyObject?)
            XCTAssertEqual(outline.numberOfRows, 1)
            try addSpawn(in: outline, content: content)
            XCTAssertEqual(outline.numberOfRows, 2)
            XCTAssertEqual(outline.selectedRow, 1)
            let spawn = try XCTUnwrap(outline.item(atRow: 1) as AnyObject?)
            XCTAssertTrue(outline.parent(forItem: spawn) as AnyObject? === root)

            XCTAssertTrue(window.makeFirstResponder(window))
            let column = try XCTUnwrap(outline.tableColumns.first)
            outline.dataSource?.outlineView?(outline, setObjectValue: "Renamed", for: column, byItem: spawn)
            XCTAssertEqual(outline.selectedRow, 1)
            XCTAssertTrue(outline.item(atRow: outline.selectedRow) as AnyObject? === spawn)
            XCTAssertEqual(outline.dataSource?.outlineView?(outline, objectValueFor: column, byItem: spawn) as? String, "Renamed")
        }
    }

    @MainActor
    func testSpawnPatternAndExceptionTablesSelectAndRemoveAddedRows() throws {
        try withSpawnEditor { window, outline, content in
            try addSpawn(in: outline, content: content)
            XCTAssertTrue(window.makeFirstResponder(window))
            let tabs = try XCTUnwrap(descendants(of: content).compactMap { $0 as? NSTabView }.first)

            for (label, tag, addAction, removeAction, text) in [
                ("Patterns", 1, "addPattern:", "removePattern:", "match this"),
                ("Exceptions", 2, "addException:", "removeException:", "except this")
            ] {
                let tab = try XCTUnwrap(tabs.tabViewItems.first { $0.label == label })
                tabs.selectTabViewItem(tab)
                let view = try XCTUnwrap(tab.view)
                let controls = descendants(of: view)
                let table = try XCTUnwrap(controls.compactMap { $0 as? NSTableView }.first { $0.tag == tag })
                let buttons = controls.compactMap { $0 as? NSButton }
                let add = try XCTUnwrap(buttons.first { $0.action == NSSelectorFromString(addAction) })
                let remove = try XCTUnwrap(buttons.first { $0.action == NSSelectorFromString(removeAction) })
                let column = try XCTUnwrap(table.tableColumns.first { $0.identifier.rawValue == "matchPattern" })

                XCTAssertEqual(table.numberOfRows, 0)
                add.performClick(nil)
                XCTAssertEqual(table.numberOfRows, 1)
                XCTAssertEqual(table.selectedRow, 0)
                XCTAssertTrue(window.makeFirstResponder(window))
                table.dataSource?.tableView?(table, setObjectValue: text, for: column, row: 0)
                XCTAssertEqual(table.dataSource?.tableView?(table, objectValueFor: column, row: 0) as? String, text)
                remove.performClick(nil)
                XCTAssertEqual(table.numberOfRows, 0)
            }
        }
    }

    @MainActor
    private func withSpawnEditor(
        _ exercise: (NSWindow, NSOutlineView, NSView) throws -> Void
    ) throws {
        let preferences = RDAtlantisWorldPreferences()
        let editor = try XCTUnwrap(WorldConfigurationEditor(world: preferences, forCharacter: nil))
        let tabs = try XCTUnwrap(editor.configView() as? NSTabView)
        let spawnTab = try XCTUnwrap(tabs.tabViewItems.first { $0.label == "Spawns" })
        tabs.selectTabViewItem(spawnTab)
        let content = try XCTUnwrap(spawnTab.view)
        let controls = descendants(of: content)
        let outline = try XCTUnwrap(controls.compactMap { $0 as? NSOutlineView }.first)
        let window = NSWindow(contentRect: content.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = tabs
        window.orderFront(nil)
        defer {
            window.close()
            withExtendedLifetime(editor) {}
        }
        try exercise(window, outline, content)
    }

    @MainActor
    private func addSpawn(in outline: NSOutlineView, content: NSView) throws {
        let buttons = descendants(of: content).compactMap { $0 as? NSButton }
        let add = try XCTUnwrap(buttons.first { $0.action == NSSelectorFromString("addSpawn:") })
        outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        add.performClick(nil)
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

@MainActor
private final class OutlineClickDelegate: NSObject, NSOutlineViewDelegate {
    private(set) var item: AnyObject?
    private(set) var column: NSTableColumn?

    @objc(outlineView:clickedItem:inColumn:)
    func outlineView(_ outlineView: NSOutlineView, clickedItem item: AnyObject, inColumn column: NSTableColumn) -> Bool {
        self.item = item
        self.column = column
        return true
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
