import AppKit
import XCTest
@testable import Atlantis

final class EventRemovalTests: XCTestCase {
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
