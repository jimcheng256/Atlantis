import XCTest
@testable import Atlantis

@MainActor
final class AtlantisProfileTests: XCTestCase {
    func testSeparateProfilesPersistPreferencesAndWorlds() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let firstPath = temporary.appendingPathComponent("first").path
        let first = try AtlantisProfile(directory: firstPath)
        let second = try AtlantisProfile(directory: temporary.appendingPathComponent("second").path)
        for name in [first.suiteName, second.suiteName] {
            addTeardownBlock {
                UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
            }
        }

        let key = "AtlantisProfileTests.\(UUID().uuidString)"
        first.defaults.set("saved", forKey: key)
        XCTAssertTrue(first.defaults.synchronize())
        XCTAssertNotEqual(first.suiteName, second.suiteName)

        let world = RDAtlantisWorldPreferences()
        world.setPreference("Profile smoke world", forKey: "atlantis.world.name", withCharacter: nil)
        let identifier = try XCTUnwrap(world.uuid())
        let firstWorlds = WorldCollection(worldDirectory: first.storagePath("worlds"))!
        firstWorlds.saveWorld(world)

        let reopened = try AtlantisProfile(directory: firstPath)
        XCTAssertEqual(reopened.suiteName, first.suiteName)
        XCTAssertEqual(reopened.defaults.string(forKey: key), "saved")
        let reopenedWorlds = WorldCollection(worldDirectory: reopened.storagePath("worlds"))!
        reopenedWorlds.loadAllWorlds()
        XCTAssertNotNil(reopenedWorlds.world(forUUID: identifier))

        let secondWorlds = WorldCollection(worldDirectory: second.storagePath("worlds"))!
        secondWorlds.loadAllWorlds()
        XCTAssertNil(secondWorlds.world(forUUID: identifier))
        XCTAssertNil(second.defaults.object(forKey: key))
        XCTAssertNil(UserDefaults.standard.object(forKey: key))
    }

    func testRejectsFileAsProfileDirectory() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try AtlantisProfile(directory: file.path))
    }

    func testDefaultPathsAndPreferencesWithoutFlag() {
        XCTAssertFalse(RDAtlantisHasProfile())
        XCTAssertTrue(RDAtlantisDefaults() === UserDefaults.standard)
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Atlantis/hotkeys.akb")
        XCTAssertEqual(RDAtlantisStoragePath("hotkeys.akb"), expected.path)
    }
}
