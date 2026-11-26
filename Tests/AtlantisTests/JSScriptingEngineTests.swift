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

    @MainActor
    func testTimeoutRunsOnceWithArgumentsAndCanBeCleared() throws {
        let directory = try makeScriptsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let engine = JSScriptingEngine(scriptsDirectory: directory)
        let state = AtlantisState(string: nil, inWorld: nil, for: nil)!
        state.setExtraData("Test MUD", forKey: "world.name")
        let result = engine.executeFunction("""
        let calls = [];
        const cancelled = setTimeout(() => calls.push("cancelled"), 10);
        clearInterval(cancelled);
        clearTimeout(cancelled);
        setTimeout(() => { throw new Error("timer failed"); });
        setTimeout(function (name, count) {
            "use strict";
            calls.push([name, count, this === globalThis, typeof AtlantisState["world.name"]]);
        }, undefined, "Ada", 2);
        setTimeout("calls.push('code')", 30);
        let done = false;
        setTimeout(() => { done = true; }, 60);
        JSON.stringify([Number.isInteger(cancelled) && cancelled > 0, calls.length])
        """, with: state) as? String

        XCTAssertEqual(result, "[true,0]")
        waitForTimers(in: engine, state: state)
        XCTAssertEqual(engine.executeFunction("JSON.stringify(calls)", with: state) as? String,
                       #"[["Ada",2,true,"undefined"],"code"]"#)
    }

    @MainActor
    func testIntervalRepeatsAndCanClearItself() throws {
        let directory = try makeScriptsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let engine = JSScriptingEngine(scriptsDirectory: directory)
        let state = AtlantisState()
        let idsAreDistinct = engine.executeFunction("""
        let ticks = [];
        let done = false;
        const id = setInterval(label => {
            ticks.push(label);
            if (ticks.length === 3) {
                clearTimeout(id);
                setTimeout(() => { done = true; }, 45);
            }
        }, 10, "tick");
        const cancelled = setInterval(() => ticks.push("cancelled"), 10);
        clearInterval(cancelled);
        id > 0 && cancelled > 0 && id !== cancelled
        """, with: state) as? Bool

        XCTAssertEqual(idsAreDistinct, true)
        waitForTimers(in: engine, state: state)
        XCTAssertEqual(engine.executeFunction("ticks", with: state) as? [String], ["tick", "tick", "tick"])
    }

    @MainActor
    func testReloadCancelsPendingTimers() throws {
        let directory = try makeScriptsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let engine = JSScriptingEngine(scriptsDirectory: directory)
        let state = AtlantisState()
        let key = "timer-test-\(UUID().uuidString)"
        let controller = try XCTUnwrap(RDPreferenceMainController())
        let scheduled = engine.executeFunction("""
        const fail = () => ScriptBridge.setTemporaryVariableForKey("fired", "\(key)");
        const timeout = setTimeout(fail, 10);
        const interval = setInterval(fail, 10);
        timeout > 0 && interval > 0
        """, with: state) as? Bool
        XCTAssertEqual(scheduled, true)

        engine.engineReinit(state)
        _ = engine.executeFunction("let done = false; setTimeout(() => { done = true; }, 60)", with: state)
        waitForTimers(in: engine, state: state)
        XCTAssertNil(controller.tempStateVar(forKey: key))
    }

    @MainActor
    private func waitForTimers(in engine: JSScriptingEngine, state: AtlantisState) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if engine.executeFunction("done", with: state) as? Bool == true {
                return
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTFail("JavaScript timer did not complete")
    }

    private func makeScriptsDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
