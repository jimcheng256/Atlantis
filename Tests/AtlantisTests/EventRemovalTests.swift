import AppKit
import XCTest
@testable import Atlantis

final class EventRemovalTests: XCTestCase {
    @MainActor
    func testUserVariableButtonsRequireConfirmationBeforeRemoving() throws {
        let preferences = RDAtlantisWorldPreferences()
        let editor = try XCTUnwrap(WorldUserconfEditor(world: preferences, forCharacter: nil))
        let view = try XCTUnwrap(editor.configTabView())
        let table = try XCTUnwrap(testPreferenceTable(in: view))
        let buttons = view.subviews.compactMap { $0 as? NSButton }
        let add = try XCTUnwrap(buttons.first { $0.title == "Add Variable" })
        let remove = try XCTUnwrap(buttons.first { $0.title == "Remove Variable" })
        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        defer { window.close() }

        XCTAssertGreaterThanOrEqual(add.frame.width, add.intrinsicContentSize.width)
        XCTAssertGreaterThanOrEqual(remove.frame.width, remove.intrinsicContentSize.width)
        remove.performClick(nil)
        XCTAssertNil(window.attachedSheet)
        add.performClick(nil)
        XCTAssertEqual(table.numberOfRows, 1)

        remove.performClick(nil)
        let cancelSheet = try XCTUnwrap(window.attachedSheet)
        XCTAssertEqual(table.numberOfRows, 1)
        window.endSheet(cancelSheet, returnCode: .alertFirstButtonReturn)
        XCTAssertEqual(table.numberOfRows, 1)

        remove.performClick(nil)
        let confirmSheet = try XCTUnwrap(window.attachedSheet)
        XCTAssertEqual(table.numberOfRows, 1)
        window.endSheet(confirmSheet, returnCode: .alertSecondButtonReturn)
        XCTAssertEqual(table.numberOfRows, 0)

        editor.finalCommit()
        let saved = preferences.preference(forKey: "atlantis.userconf", withCharacter: nil, fallback: false)
        XCTAssertEqual(saved as? [String: String], [:])
    }

    @MainActor
    func testRemoveHighlightWaitsForConfirmationBeforeSaving() throws {
        let preferences = RDAtlantisWorldPreferences()
        let editor = try XCTUnwrap(WorldHighlightEditor(world: preferences, forCharacter: nil))
        let view = try XCTUnwrap(editor.configTabView())
        let table = try XCTUnwrap(testPreferenceTable(in: view))
        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        defer { window.close() }

        editor.addHighlight(nil)
        editor.finalCommit()
        let key = "atlantis.highlights"

        editor.removeHighlight(nil)
        let cancelSheet = try XCTUnwrap(window.attachedSheet)
        XCTAssertEqual(table.numberOfRows, 1)
        window.endSheet(cancelSheet, returnCode: .alertFirstButtonReturn)
        XCTAssertEqual(table.numberOfRows, 1)
        XCTAssertEqual((preferences.preference(forKey: key, withCharacter: nil, fallback: false) as? [Any])?.count, 1)

        editor.removeHighlight(nil)
        let confirmSheet = try XCTUnwrap(window.attachedSheet)
        XCTAssertEqual(table.numberOfRows, 1)
        window.endSheet(confirmSheet, returnCode: .alertSecondButtonReturn)
        XCTAssertEqual(table.numberOfRows, 0)
        XCTAssertNil(preferences.preference(forKey: key, withCharacter: nil, fallback: false))
    }

    @MainActor
    func testRemoveEventWaitsForConfirmation() throws {
        let collection = ToolbarCollection()
        let editor = EventEditor()
        editor.confirmsEventRemoval = true
        editor.setDataRepresentation(collection)
        editor.setForEventType(ToolbarUserEvent())
        let delegate = ToolbarEventEditorDelegate(editor: editor, collection: collection)
        delegate.addEvent()
        let event = try XCTUnwrap(collection.events()?.first as? ToolbarUserEvent)
        let view = try XCTUnwrap(editor.editorView())
        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        defer { window.close() }

        editor.removeEvent(nil)
        let cancelSheet = try XCTUnwrap(window.attachedSheet)
        XCTAssertEqual(collection.eventsCount(), 1)
        window.endSheet(cancelSheet, returnCode: .alertFirstButtonReturn)
        XCTAssertTrue(collection.events()?.first as AnyObject === event)

        editor.removeEvent(nil)
        let confirmSheet = try XCTUnwrap(window.attachedSheet)
        XCTAssertEqual(collection.eventsCount(), 1)
        window.endSheet(confirmSheet, returnCode: .alertSecondButtonReturn)
        XCTAssertEqual(collection.eventsCount(), 0)
    }
}
