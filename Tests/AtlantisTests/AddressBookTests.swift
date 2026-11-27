import AppKit
import XCTest
@testable import Atlantis

final class AddressBookTests: XCTestCase {
    @MainActor
    func testOutlineDisplaysWorldsAndTheirCharacters() throws {
        try withAddressBook { _, _, outline, _ in
            let dataSource = try XCTUnwrap(outline.dataSource)
            let column = try XCTUnwrap(outline.tableColumns.first { $0.identifier.rawValue == "worldName" })
            XCTAssertEqual(outline.numberOfRows, 1)
            let worldItem = try XCTUnwrap(outline.item(atRow: 0) as AnyObject?)
            XCTAssertEqual(dataSource.outlineView?(outline, objectValueFor: column, byItem: worldItem) as? String, "Outline fixture")

            outline.expandItem(worldItem)
            XCTAssertEqual(outline.numberOfRows, 2)
            let characterItem = try XCTUnwrap(outline.item(atRow: 1) as AnyObject?)
            XCTAssertTrue(outline.parent(forItem: characterItem) as AnyObject? === worldItem)
            XCTAssertEqual(dataSource.outlineView?(outline, objectValueFor: column, byItem: characterItem) as? String, "Test Character")
            outline.collapseItem(worldItem)
            XCTAssertEqual(outline.numberOfRows, 1)
        }
    }

    @MainActor
    func testEditorTabRestorationChecksTheDestinationTabs() throws {
        try withAddressBook { _, content, outline, world in
            let configuration = try XCTUnwrap(findSubview(NSTabView.self, in: content))
            let worldID = try XCTUnwrap(world.uuid())
            let characterID = try XCTUnwrap(world.uuid(forCharacter: "Test Character"))
            let worldPage = try XCTUnwrap(configuration.tabViewItems.first { $0.identifier as? String == worldID })
            let characterPage = try XCTUnwrap(configuration.tabViewItems.first { $0.identifier as? String == characterID })
            let worldTabs = try XCTUnwrap(worldPage.view as? NSTabView)
            let characterTabs = try XCTUnwrap(characterPage.view as? NSTabView)
            let worldItem = try XCTUnwrap(outline.item(atRow: 0))

            outline.expandItem(worldItem)
            outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            worldTabs.selectTabViewItem(at: 1)
            outline.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
            XCTAssertTrue(configuration.selectedTabViewItem === characterPage)
            XCTAssertTrue(characterTabs.selectedTabViewItem === characterTabs.tabViewItem(at: 1))

            outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            let extra = NSTabViewItem(identifier: "Test-only extra tab")
            worldTabs.addTabViewItem(extra)
            defer { worldTabs.removeTabViewItem(extra) }
            XCTAssertGreaterThanOrEqual(worldTabs.tabViewItems.count - 1, characterTabs.tabViewItems.count)
            worldTabs.selectTabViewItem(extra)
            characterTabs.selectTabViewItem(at: 0)
            outline.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
            XCTAssertTrue(configuration.selectedTabViewItem === characterPage)
            XCTAssertTrue(characterTabs.selectedTabViewItem === characterTabs.tabViewItem(at: 0))
        }
    }

    @MainActor
    func testAddingAndFocusingSelectsTheRequestedRecord() throws {
        try withAddressBook { book, _, outline, world in
            let dataSource = try XCTUnwrap(outline.dataSource)
            let column = try XCTUnwrap(outline.tableColumns.first { $0.identifier.rawValue == "worldName" })
            book.addWorld(nil)
            let addedWorld = try XCTUnwrap(outline.item(atRow: outline.selectedRow) as AnyObject?)
            XCTAssertEqual(dataSource.outlineView?(outline, objectValueFor: column, byItem: addedWorld) as? String, "<world01>")

            book.addCharacter(nil)
            let addedCharacter = try XCTUnwrap(outline.item(atRow: outline.selectedRow) as AnyObject?)
            XCTAssertTrue(outline.parent(forItem: addedCharacter) as AnyObject? === addedWorld)
            XCTAssertEqual(dataSource.outlineView?(outline, objectValueFor: column, byItem: addedCharacter) as? String, "<character01>")

            book.focusWorld(world, forCharacter: "Test Character")
            let focused = try XCTUnwrap(outline.item(atRow: outline.selectedRow))
            XCTAssertEqual(dataSource.outlineView?(outline, objectValueFor: column, byItem: focused) as? String, "Test Character")
        }
    }

    @MainActor
    func testConnectionColumnAndNewCharacterEditorTab() throws {
        try withAddressBook { book, content, outline, world in
            XCTAssertEqual(outline.tableColumns.first?.identifier.rawValue, "worldConnected")
            let configuration = try XCTUnwrap(findSubview(NSTabView.self, in: content))
            let tabsBefore = configuration.tabViewItems.count

            outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            book.addCharacter(nil)

            let identifier = try XCTUnwrap(world.uuid(forCharacter: "<character01>"))
            let characterTabs = configuration.tabViewItems.filter { $0.identifier as? String == identifier }
            XCTAssertEqual(configuration.tabViewItems.count, tabsBefore + 1)
            XCTAssertEqual(characterTabs.count, 1)
            let characterTab = try XCTUnwrap(characterTabs.first)
            XCTAssertTrue(configuration.selectedTabViewItem === characterTab)
            XCTAssertNotNil(characterTab.view as? NSTabView)
        }
    }

    @MainActor
    private func withAddressBook(
        _ exercise: (AddressBook, NSView, NSOutlineView, RDAtlantisWorldPreferences) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let collection = try XCTUnwrap(WorldCollection(worldDirectory: directory.path))
        let book = AddressBook()
        let window = try XCTUnwrap(book.window)
        let content = try XCTUnwrap(window.contentView)
        let outline = try XCTUnwrap(findSubview(NSOutlineView.self, in: content))

        book.setWorldCollection(collection)
        XCTAssertEqual(outline.numberOfRows, 0)

        let world = RDAtlantisWorldPreferences()
        world.setPreference("Outline fixture", forKey: "atlantis.world.name", withCharacter: nil)
        world.addCharacter("Test Character")
        defer {
            window.orderOut(nil)
            for case let fixture as RDAtlantisWorldPreferences in collection.worlds() {
                if let identifier = fixture.uuid() {
                    RDAtlantisDefaults().removeObject(forKey: "addressbook.expands:\(identifier)")
                }
            }
            withExtendedLifetime(book) {}
        }
        collection.addWorld(world)
        book.setWorldCollection(collection)
        try exercise(book, content, outline, world)
    }

    @MainActor
    private func findSubview<View: NSView>(_ type: View.Type, in view: NSView) -> View? {
        (view as? View) ?? view.subviews.lazy.compactMap { self.findSubview(type, in: $0) }.first
    }
}
