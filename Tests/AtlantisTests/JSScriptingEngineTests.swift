import XCTest
@testable import Atlantis

final class JSScriptingEngineTests: XCTestCase {
    @MainActor
    func testLoadsGameScriptAndCallsFunctionsWithEventState() throws {
        let directory = try makeScriptsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try """
        let visits = 0;
        function visit() {
            return AtlantisState["world.name"] + ":" + ++visits;
        }
        function greet(name) {
            return AtlantisState["world.name"] + " says hello to " + name;
        }
        """.write(to: directory.appendingPathComponent("game.js"), atomically: true, encoding: .utf8)

        let engine = JSScriptingEngine(scriptsDirectory: directory)
        let state = AtlantisState(string: nil, inWorld: nil, for: nil)!
        state.setExtraData("Test MUD", forKey: "world.name")

        XCTAssertTrue(engine.engineNeedsReinit())
        XCTAssertEqual(engine.executeFunction("visit", with: state) as? String, "Test MUD:1")
        XCTAssertFalse(engine.engineNeedsReinit())
        XCTAssertEqual(engine.executeFunction("visit()", with: state) as? String, "Test MUD:2")

        state.setExtraData("command", forKey: "event.cause")
        state.setExtraData(["RDOptsFullString": "O'Neil\nSmith"], forKey: "RDCommandParams")
        XCTAssertEqual(engine.executeFunction("greet", with: state) as? String, "Test MUD says hello to O'Neil\nSmith")
        XCTAssertEqual(engine.executeFunction("greet('Ada')", with: state) as? String, "Test MUD says hello to Ada")
    }

    @MainActor
    func testGameScriptCallsNativeBridge() throws {
        let directory = try makeScriptsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try """
        const missingWorld = "missing-world-\(UUID().uuidString)";
        function lookup() {
            return [
                ScriptBridge.worldUuidForName(missingWorld),
                ScriptBridge.getPreferenceInWorld("motd", missingWorld),
                ScriptBridge.charactersForWorld(missingWorld).length,
                typeof ScriptBridge.sendTextToWorld,
                typeof ScriptBridge.registerFunctionForLinePatternWithLanguageInWorld,
                typeof ScriptBridge.instanceForUuidWithCharacter
            ];
        }
        """.write(to: directory.appendingPathComponent("bridge.js"), atomically: true, encoding: .utf8)

        let engine = JSScriptingEngine(scriptsDirectory: directory)
        let result = try XCTUnwrap(engine.executeFunction("lookup()", with: AtlantisState()) as? [Any])
        XCTAssertEqual(result.count, 6)
        XCTAssertEqual(result[0] as? String, "")
        XCTAssertEqual(result[1] as? String, "")
        XCTAssertEqual(result[2] as? Int, 0)
        XCTAssertEqual(result[3] as? String, "function")
        XCTAssertEqual(result[4] as? String, "function")
        XCTAssertEqual(result[5] as? String, "undefined")
    }

    @MainActor
    func testReloadRemovesOldGlobalsAndContinuesAfterScriptErrors() throws {
        let directory = try makeScriptsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let game = directory.appendingPathComponent("game.js")
        try "function oldHandler() { return 1; }".write(to: game, atomically: true, encoding: .utf8)
        let badScript = directory.appendingPathComponent("broken.js")
        try "throw new Error('load failed');".write(to: badScript, atomically: true, encoding: .utf8)

        var reloads = 0
        let engine = JSScriptingEngine(scriptsDirectory: directory) { reloads += 1 }
        let state = AtlantisState()
        XCTAssertEqual(engine.executeFunction("oldHandler()", with: state) as? Int, 1)
        XCTAssertNil(engine.executeFunction("throw new Error('event failed')", with: state))
        XCTAssertEqual(engine.executeFunction("oldHandler()", with: state) as? Int, 1)

        try "function newHandler() { return 200; }".write(to: game, atomically: true, encoding: .utf8)
        XCTAssertTrue(engine.engineNeedsReinit())
        engine.engineReinit(state)
        XCTAssertFalse(engine.engineNeedsReinit())
        XCTAssertEqual(engine.executeFunction("typeof oldHandler", with: state) as? String, "undefined")
        XCTAssertEqual(engine.executeFunction("newHandler()", with: state) as? Int, 200)
        XCTAssertEqual(reloads, 2)

        try FileManager.default.removeItem(at: game)
        XCTAssertTrue(engine.engineNeedsReinit())
    }

    private func makeScriptsDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
