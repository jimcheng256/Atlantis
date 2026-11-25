import AppKit
import XCTest
@testable import Atlantis

final class HotkeyPreferencesTests: XCTestCase {
    @MainActor
    func testKeyCaptureAddsOnlyValidCombinationsAndSelectsTheNewRow() throws {
        let collection = HotkeyCollection()
        let editor = EventEditor()
        editor.setDataRepresentation(collection)
        editor.setForEventType(HotkeyEvent())
        let delegate = HotkeyEditorDelegate(editor: editor, collection: collection)
        let panel = PTKeyComboPanel()
        panel.setKeyCombo(PTKeyCombo(keyCode: -1, modifiers: -1))
        delegate.keyComboPanelEnded(panel)
        XCTAssertEqual(collection.eventsCount(), 0)

        panel.setKeyCombo(PTKeyCombo(keyCode: 12, modifiers: 256))
        delegate.keyComboPanelEnded(panel)
        XCTAssertEqual(collection.eventsCount(), 1)
        let event = try XCTUnwrap(collection.events()?.first as? HotkeyEvent)
        XCTAssertTrue(event.eventIsEnabled())
        XCTAssertEqual(testPreferenceTable(in: editor.editorView())?.selectedRow, 0)

        let action = BaseAction()
        delegate.newActionPicked(action, context: Unmanaged.passUnretained(event).toOpaque())
        XCTAssertTrue(event.eventActions()?.first as AnyObject === action)
    }

    @MainActor
    func testCommitRoundTripsLegacyArchive() throws {
        let collection = HotkeyCollection()
        let editor = EventEditor()
        editor.setDataRepresentation(collection)
        editor.setForEventType(HotkeyEvent())
        let delegate = HotkeyEditorDelegate(editor: editor, collection: collection)
        delegate.addKey(PTKeyCombo(keyCode: 12, modifiers: 256))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("hotkeys.akb")
        let pane = HotkeyPreferences(collection: collection, archiveURL: url)
        pane.preferencePaneCommit()

        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? HotkeyCollection)
        let event = try XCTUnwrap(decoded.events()?.first as? HotkeyEvent)
        XCTAssertEqual(event.keyCombo().keyCode(), 12)
        XCTAssertEqual(event.keyCombo().modifiers(), 256)
    }
}

@MainActor
func testPreferenceTable(in view: NSView) -> NSTableView? {
    if let table = view as? NSTableView { return table }
    return view.subviews.lazy.compactMap { testPreferenceTable(in: $0) }.first
}
