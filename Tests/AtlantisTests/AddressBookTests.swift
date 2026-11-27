import AppKit
import XCTest
@testable import Atlantis

final class AddressBookTests: XCTestCase {
    @MainActor
    func testOutlineDisplaysWorldsAndTheirCharacters() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let collection = try XCTUnwrap(WorldCollection(worldDirectory: directory.path))
        let book = AddressBook()
        let window = try XCTUnwrap(book.window)
        let content = try XCTUnwrap(window.contentView)
        let outline = try XCTUnwrap(findOutline(in: content))

        book.setWorldCollection(collection)
        XCTAssertEqual(outline.numberOfRows, 0)

        let world = RDAtlantisWorldPreferences()
        world.setPreference("Outline fixture", forKey: "atlantis.world.name", withCharacter: nil)
        world.addCharacter("Test Character")
        let identifier = try XCTUnwrap(world.uuid())
        defer { RDAtlantisDefaults().removeObject(forKey: "addressbook.expands:\(identifier)") }
        collection.addWorld(world)
        book.setWorldCollection(collection)

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
        withExtendedLifetime(book) {}
    }

    @MainActor
    private func findOutline(in view: NSView) -> NSOutlineView? {
        (view as? NSOutlineView) ?? view.subviews.lazy.compactMap { self.findOutline(in: $0) }.first
    }
}
