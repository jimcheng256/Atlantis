import AppKit
import Network
import XCTest
@testable import Atlantis

@MainActor
final class ApplicationSmokeTests: XCTestCase {
    func testWorldConnectsDisplaysOutputAndReconnects() async throws {
        let environment = ProcessInfo.processInfo.environment
        if let profile = environment["ATLANTIS_SMOKE_PROFILE"] {
            XCTAssertTrue(RDAtlantisHasProfile())
            XCTAssertEqual(Bundle.main.bundleIdentifier, environment["ATLANTIS_SMOKE_BUNDLE_ID"])
            let expected = URL(fileURLWithPath: profile).appendingPathComponent("worlds")
            let actual = URL(fileURLWithPath: RDAtlantisStoragePath("worlds"))
            XCTAssertEqual(actual.resolvingSymlinksInPath().path, expected.resolvingSymlinksInPath().path)
        }
        let fixture = try LoopbackFixture()
        defer { fixture.stop() }
        try await waitFor("fixture to listen") { (fixture.listener.port?.rawValue ?? 0) > 0 }
        let port = try XCTUnwrap(fixture.listener.port)
        let name = "Smoke \(UUID())"
        let preferences = RDAtlantisWorldPreferences()
        preferences.setPreference(name, forKey: "atlantis.world.name", withCharacter: nil)
        preferences.setPreference("127.0.0.1", forKey: "atlantis.world.host", withCharacter: nil)
        preferences.setPreference(Int(port.rawValue), forKey: "atlantis.world.port", withCharacter: nil)
        preferences.setPreference(String.Encoding.utf8.rawValue, forKey: "atlantis.encoding", withCharacter: nil)
        preferences.setPreference(true, forKey: "atlantis.text.linefeed", withCharacter: nil)
        preferences.setPreference(true, forKey: "atlantis.world.temporary", withCharacter: nil)
        let world = try XCTUnwrap(RDAtlantisWorldInstance(world: preferences, forCharacter: nil, withBasePath: name))
        defer { world.closeAndRemove() }
        let spawn = try XCTUnwrap(world.mainSpawn())
        let output = spawn.controller.outputView

        for index in 0..<2 {
            world.connect()
            try await waitFor("session \(index + 1) to connect") {
                fixture.connections.count > index && world.isConnected()
            }

            let banner = "Smoke \(index + 1)"
            fixture.send(Data("\u{1B}[31m\(banner)\u{1B}[0m\r\n\u{1B}[38;2;12;34;".utf8), to: index)
            try await waitFor("banner to appear") {
                _ = output.commit()
                return output.string.contains(banner)
            }
            let prompt = "Prompt \(index + 1)> "
            // Telnet Go Ahead marks the end of a prompt without a trailing newline.
            var promptBytes = Data("56m\(prompt)\u{1B}[0m".utf8)
            promptBytes.append(contentsOf: [255, 249])
            fixture.send(promptBytes, to: index)
            try await waitFor("split prompt to appear") {
                _ = output.commit()
                return output.string.contains(prompt)
            }
            let storage = try XCTUnwrap(output.textStorage)
            let location = (storage.string as NSString).range(of: prompt).location
            let color = try XCTUnwrap(storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor)
            let rgb = try XCTUnwrap(color.usingColorSpace(.sRGB))
            XCTAssertEqual(rgb.redComponent, 12.0 / 255.0, accuracy: 0.01)
            XCTAssertEqual(rgb.greenComponent, 34.0 / 255.0, accuracy: 0.01)
            XCTAssertEqual(rgb.blueComponent, 56.0 / 255.0, accuracy: 0.01)

            world.processInputString("say smoke", on: spawn)
            world.processInputString("say café", on: spawn)
            let expected = Data("say smoke\r\nsay café\r\n".utf8)
            try await waitFor("command bytes to arrive") {
                fixture.received[index].count >= expected.count
            }
            XCTAssertEqual(fixture.received[index], expected)
            world.disconnect()
            try await waitFor("session \(index + 1) to disconnect") {
                !world.isConnected() && fixture.closed.contains(index)
            }
            XCTAssertEqual(fixture.received[index], expected)
        }
    }

    private func waitFor(_ description: String, condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                throw SmokeError.timeout(description)
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private enum SmokeError: LocalizedError {
        case timeout(String)

        var errorDescription: String? {
            switch self {
            case .timeout(let description): return "Timed out waiting for \(description)"
            }
        }
    }
}

@MainActor
private final class LoopbackFixture {
    let listener: NWListener
    private(set) var connections: [NWConnection] = []
    private(set) var received: [Data] = []
    private(set) var closed: Set<Int> = []

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.start(connection) }
        }
        listener.start(queue: .main)
    }

    func send(_ data: Data, to index: Int) {
        connections[index].send(content: data, completion: .idempotent)
    }

    func stop() {
        listener.cancel()
        for connection in connections { connection.cancel() }
    }

    private func start(_ connection: NWConnection) {
        let index = connections.count
        connections.append(connection)
        received.append(Data())
        connection.start(queue: .main)
        receive(connection, at: index)
    }

    private func receive(_ connection: NWConnection, at index: Int) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data { self.received[index].append(data) }
                if complete {
                    self.closed.insert(index)
                } else if error == nil {
                    self.receive(connection, at: index)
                }
            }
        }
    }
}
