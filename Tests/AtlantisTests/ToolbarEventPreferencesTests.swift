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
    func testConditionsTabReturnsAfterSwitchingEventTypes() throws {
        let collection = EventCollection()
        let supported = ToolbarUserEvent()
        let unsupported = HotkeyEvent()
        collection.addEvent(supported)
        collection.addEvent(unsupported)
        let editor = EventEditor()
        editor.setDataRepresentation(collection)
        let content = try XCTUnwrap(editor.editorView())
        let window = NSWindow(contentRect: content.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.orderFront(nil)
        defer { window.close() }

        func findTabs(in view: NSView) -> NSTabView? {
            if let tabs = view as? NSTabView { return tabs }
            return view.subviews.lazy.compactMap { findTabs(in: $0) }.first
        }
        let tabs = try XCTUnwrap(findTabs(in: content))
        let conditions = try XCTUnwrap(tabs.tabViewItems.first { $0.identifier as? String == "eventConds" })

        editor.setForEventType(unsupported)
        XCTAssertFalse(tabs.tabViewItems.contains(conditions))
        XCTAssertEqual(tabs.tabViewType, .noTabsNoBorder)
        editor.setForEventType(supported)
        XCTAssertTrue(tabs.tabViewItems.contains(conditions))
        XCTAssertEqual(tabs.tabViewType, .topTabsBezelBorder)

        editor.selectEvent(unsupported)
        XCTAssertFalse(tabs.tabViewItems.contains(conditions))
        XCTAssertEqual(tabs.tabViewType, .noTabsNoBorder)
        editor.selectEvent(supported)
        XCTAssertTrue(tabs.tabViewItems.contains(conditions))
        XCTAssertEqual(tabs.tabViewType, .topTabsBezelBorder)
    }

    @MainActor
    func testReorderingKeepsTheMovedEventSelected() throws {
        let collection = ToolbarCollection()
        let first = ToolbarUserEvent()
        let second = ToolbarUserEvent()
        collection.addEvent(first)
        collection.addEvent(second)
        let editor = EventEditor()
        editor.setDataRepresentation(collection)
        let view = try XCTUnwrap(editor.editorView())
        let table = try XCTUnwrap(testPreferenceTable(in: view))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        defer { window.close() }

        editor.selectEvent(first)
        editor.selectEvent(ToolbarUserEvent())
        XCTAssertEqual(table.selectedRow, 0)
        editor.moveEventUp(nil)
        XCTAssertEqual(table.selectedRow, 0)
        XCTAssertTrue(collection.events()?.first as AnyObject === first)
        editor.moveEventDown(nil)
        XCTAssertEqual(table.selectedRow, 1)
        XCTAssertTrue(collection.events()?.last as AnyObject === first)
        editor.moveEventDown(nil)
        XCTAssertEqual(table.selectedRow, 1)
        XCTAssertTrue(collection.events()?.last as AnyObject === first)
        editor.moveEventUp(nil)
        XCTAssertEqual(table.selectedRow, 0)
        XCTAssertTrue(collection.events()?.first as AnyObject === first)
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
