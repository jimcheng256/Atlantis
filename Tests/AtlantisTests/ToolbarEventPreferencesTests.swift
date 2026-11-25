import AppKit
import XCTest
@testable import Atlantis

final class ToolbarEventPreferencesTests: XCTestCase {
    @MainActor
    func testNewEventUsesSharedCollectionAndAndsConditions() throws {
        let collection = ToolbarCollection()
        let editor = EventEditor()
        editor.setDataRepresentation(collection)
        editor.setForEventType(ToolbarUserEvent())
        let delegate = ToolbarEventEditorDelegate(editor: editor, collection: collection)
        delegate.addEvent()
        XCTAssertEqual(collection.eventsCount(), 1)
        let first = try XCTUnwrap(collection.events()?.first as? ToolbarUserEvent)
        XCTAssertTrue(first.eventConditionsAnded())
        XCTAssertEqual(testPreferenceTable(in: editor.editorView())?.selectedRow, 0)

        delegate.addEvent()
        let second = try XCTUnwrap(collection.events()?.last as? ToolbarUserEvent)
        let context = Unmanaged.passUnretained(first).toOpaque()
        let action = BaseAction()
        let condition = BaseCondition()
        delegate.newActionPicked(action, context: context)
        delegate.newConditionPicked(condition, context: context)
        XCTAssertTrue(first.eventActions()?.first as AnyObject === action)
        XCTAssertTrue(first.eventConditions()?.first as AnyObject === condition)
        XCTAssertTrue(second.eventActions()?.isEmpty ?? false)
        XCTAssertTrue(second.eventConditions()?.isEmpty ?? false)
    }

    @MainActor
    func testCommitCallsSaveAndUsesLegacyArchive() throws {
        let collection = ToolbarCollection()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("toolbarEvents.atb")
        let editor = EventEditor()
        editor.setDataRepresentation(collection)
        editor.setForEventType(ToolbarUserEvent())
        ToolbarEventEditorDelegate(editor: editor, collection: collection).addEvent()
        var saves = 0
        let pane = ToolbarEventPreferences(collection: collection) {
            saves += 1
            XCTAssertTrue(NSKeyedArchiver.archiveRootObject(collection, toFile: url.path))
        }
        pane.preferencePaneCommit()

        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? ToolbarCollection)
        XCTAssertEqual(saves, 1)
        let event = try XCTUnwrap(decoded.events()?.first as? ToolbarUserEvent)
        XCTAssertTrue(event.eventConditionsAnded())
    }
}
