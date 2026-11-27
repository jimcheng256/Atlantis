import AppKit
import WebKit
import XCTest
@testable import Atlantis

@MainActor
final class ANSIColorTests: XCTestCase {
    func testTelnetAdvertisesTruecolorAndRestartsTerminalTypeCycle() {
        let world = ColorTestWorld()
        let filter = RDTelnetFilter(world: world)!
        let connected = Notification.Name("RDAtlantisConnectionDidConnectNotification")
        let disconnected = Notification.Name("RDAtlantisConnectionDidDisconnectNotification")
        let request: [UInt8] = [255, 250, 24, 1, 255, 240]

        func input(_ bytes: [UInt8]) {
            let data = NSMutableData(data: Data(bytes))
            filter.filterInput(data)
            XCTAssertEqual(data.length, 0)
        }

        func reply(_ terminalType: String) -> Data {
            Data([255, 250, 24, 0] + Array(terminalType.utf8) + [255, 240])
        }

        NotificationCenter.default.post(name: connected, object: world)
        input([255, 253, 24])
        input([255, 250, 24, 255, 240])
        input(request + request + request + request)
        XCTAssertEqual(world.telnetReplies, [
            Data([255, 251, 24]), reply("Atlantis"), reply("xterm-256color"),
            reply("MTTS 269"), reply("MTTS 269")
        ])

        world.telnetReplies.removeAll()
        input(request)
        input([255, 254, 24])
        input([255, 253, 24])
        input(request + request)
        XCTAssertEqual(world.telnetReplies, [
            reply("Atlantis"), Data([255, 252, 24]), Data([255, 251, 24]),
            reply("Atlantis"), reply("xterm-256color")
        ])

        world.telnetReplies.removeAll()
        NotificationCenter.default.post(name: disconnected, object: world)
        NotificationCenter.default.post(name: connected, object: world)
        input([255, 253, 24] + request)
        XCTAssertEqual(world.telnetReplies, [Data([255, 251, 24]), reply("Atlantis")])
    }

    func testTelnetCharsetPrefersUTF8ThenASCIIAndRejectsUnsupportedOffers() {
        let world = ColorTestWorld()
        let filter = RDTelnetFilter(world: world)!

        func input(_ request: [UInt8], accepted: String?) {
            world.telnetReplies.removeAll()
            let frame = NSMutableData(data: Data([255, 250, 42, 1] + request + [255, 240]))
            filter.filterInput(frame)
            let response: [UInt8] = accepted.map { [2] + Array($0.utf8) } ?? [3]
            XCTAssertEqual(world.telnetReplies, [Data([255, 250, 42] + response + [255, 240])])
            XCTAssertEqual(frame.length, 0)
        }

        world.setStringEncoding(String.Encoding.isoLatin1.rawValue)
        input(Array(";ISO-8859-1;US-ASCII;utf-8".utf8), accepted: "utf-8")
        XCTAssertEqual(world.stringEncoding(), String.Encoding.utf8.rawValue)
        input(Array(";ISO-8859-1;US-ASCII".utf8), accepted: "US-ASCII")
        XCTAssertEqual(world.stringEncoding(), String.Encoding.ascii.rawValue)
        input(Array("[TTABLE]".utf8) + [1] + Array("|unknown|ISO-8859-1".utf8), accepted: "ISO-8859-1")
        XCTAssertEqual(world.stringEncoding(), String.Encoding.isoLatin1.rawValue)
        input(Array(";unknown".utf8), accepted: nil)
        input([], accepted: nil)
        XCTAssertEqual(world.stringEncoding(), String.Encoding.isoLatin1.rawValue)
    }

    func testNegotiatedEncodingSheetOffersToSaveOncePerWorld() async throws {
        for save in [false, true] {
            let world = ColorTestWorld()
            let preferences = RDAtlantisWorldPreferences()
            preferences.setPreference(true, forKey: "atlantis.world.temporary", withCharacter: nil)
            preferences.setPreference("Encoding Test", forKey: "atlantis.world.name", withCharacter: nil)
            preferences.setPreference(String.Encoding.isoLatin1.rawValue, forKey: "atlantis.encoding", withCharacter: nil)
            world.storedWorldPreferences = preferences
            let path = "Charset Test \(UUID())"
            let spawn = RDAtlantisSpawn(path: path, forInstance: world, withPrefs: nil)
            world.promptSpawn = spawn
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 500, height: 300),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = spawn.view()
            window.orderFront(nil)
            defer {
                window.close()
                world.promptSpawn = nil
                UserDefaults.standard.removeObject(forKey: "RBSplitView H \(path)")
            }

            world.applyNegotiatedStringEncoding(String.Encoding.isoLatin1.rawValue)
            XCTAssertNil(preferences.preference(forKey: "atlantis.encoding.negotiationPrompted",
                                                 withCharacter: nil, fallback: false))
            world.applyNegotiatedStringEncoding(String.Encoding.utf8.rawValue)
            XCTAssertEqual(world.stringEncoding(), String.Encoding.utf8.rawValue)
            for _ in 0..<40 where window.attachedSheet == nil {
                try await Task.sleep(for: .milliseconds(25))
            }
            let sheet = try XCTUnwrap(window.attachedSheet)
            let button = try XCTUnwrap(button(in: sheet.contentView, titled: save ? "Save Encoding" : "Keep Current Setting"))
            button.performClick(nil)
            for _ in 0..<40 where window.attachedSheet != nil {
                try await Task.sleep(for: .milliseconds(25))
            }

            let expected = save ? String.Encoding.utf8.rawValue : String.Encoding.isoLatin1.rawValue
            let archive = try NSKeyedArchiver.archivedData(withRootObject: preferences, requiringSecureCoding: false)
            let reloaded = try XCTUnwrap(NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archive) as? RDAtlantisWorldPreferences)
            XCTAssertEqual(reloaded.preference(forKey: "atlantis.encoding", withCharacter: nil, fallback: false) as? UInt, expected)
            XCTAssertEqual(reloaded.preference(forKey: "atlantis.encoding.negotiationPrompted",
                                              withCharacter: nil, fallback: false) as? Bool, true)
            world.storedWorldPreferences = reloaded
            world.applyNegotiatedStringEncoding(String.Encoding.ascii.rawValue)
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertNil(window.attachedSheet)
            XCTAssertEqual(world.stringEncoding(), String.Encoding.ascii.rawValue)
        }
    }

    private func button(in view: NSView?, titled title: String) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton, button.title == title { return button }
        return view.subviews.lazy.compactMap { self.button(in: $0, titled: title) }.first
    }

    func testPlainTextUsesWorldDefaultsAcrossChunks() {
        let fixture = Fixture()
        for text in ["plain text\n", "prompt> "] {
            let output = fixture.input(text)
            XCTAssertEqual(output.string, text)
            assertColors(output, foreground: fixture.world.foreground, background: fixture.world.background)
        }
    }

    func testBasicBrightAndIndexedColors() {
        let fixture = Fixture()
        let palette = fixture.world.palette
        for (sequence, foreground, background, foregroundIndex, backgroundIndex) in [
            ("31;44", palette[1], palette[4], 1, 4),
            ("91;104", palette[9], palette[12], 9, 12),
            ("38;5;12;48;5;3", palette[12], palette[3], 12, 3)
        ] {
            let output = fixture.sgr(sequence)
            assertColors(output, foreground: foreground, background: background,
                         foregroundIndex: foregroundIndex, backgroundIndex: backgroundIndex)
        }
        assertColors(fixture.sgr("38;5;196;48;5;232"),
                     foreground: NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1),
                     background: NSColor(calibratedWhite: 8.0 / 255, alpha: 1).usingColorSpace(.genericRGB)!)
    }

    func testCombinedStylesAndSplitSequenceAtPrompt() {
        let fixture = Fixture()
        let palette = fixture.world.palette
        XCTAssertEqual(fixture.input("before\u{1B}[31;").string, "before")
        let output = fixture.input("44;1;4;7mprompt> ")
        XCTAssertEqual(output.string, "prompt> ")
        assertColors(output, foreground: palette[4], background: palette[9],
                     foregroundIndex: 4, backgroundIndex: 9)
        XCTAssertEqual(output.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int,
                       NSUnderlineStyle.single.rawValue)
        assertColors(fixture.sgr("22"), foreground: palette[4], background: palette[9],
                     foregroundIndex: 4, backgroundIndex: 9)
        assertColors(fixture.sgr("27;21;24"), foreground: palette[1], background: palette[4],
                     foregroundIndex: 1, backgroundIndex: 4)
        assertColors(fixture.sgr("39;49"), foreground: fixture.world.foreground,
                     background: fixture.world.background)
        assertColors(fixture.sgr("31;44;0"), foreground: fixture.world.foreground,
                     background: fixture.world.background)
    }

    func testRGBTransitionsWithPaletteStylesAndResets() {
        let fixture = Fixture()
        let world = fixture.world
        let palette = world.palette
        let orange = rgb(255, 1, 32)
        let blue = rgb(0, 64, 255)
        let output = fixture.input("\u{1B}[31;44mA\u{1B}[38;2;255;1;32mB\u{1B}[48:2::0:64:255mC")
        XCTAssertEqual(output.string, "ABC")
        assertColors(output, foreground: palette[1], background: palette[4],
                     foregroundIndex: 1, backgroundIndex: 4)
        assertColors(output, foreground: orange, background: palette[4], backgroundIndex: 4, at: 1)
        assertColors(output, foreground: orange, background: blue, at: 2)

        let bold = fixture.sgr("1;4;7")
        assertColors(bold, foreground: blue, background: orange)
        XCTAssertEqual(bold.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int,
                       NSUnderlineStyle.single.rawValue)
        let plain = fixture.sgr("21;24;27")
        assertColors(plain, foreground: orange, background: blue)
        XCTAssertEqual(plain.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int,
                       0)
        let boldFont = bold.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let plainFont = plain.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotEqual(boldFont, plainFont)

        assertColors(fixture.sgr("7;91"), foreground: blue, background: palette[9], backgroundIndex: 9)
        assertColors(fixture.sgr("49"), foreground: world.background, background: palette[9], backgroundIndex: 9)
        assertColors(fixture.sgr("27;38:2:0:255:1:32;48;5;12"), foreground: orange,
                     background: palette[12], backgroundIndex: 12)
        assertColors(fixture.sgr("39"), foreground: world.foreground,
                     background: palette[12], backgroundIndex: 12)
        assertColors(fixture.sgr("38;5;196;48;2;0;64;255"), foreground: NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1),
                     background: blue)
        assertColors(fixture.sgr("38:2:255:1:32;7;0"), foreground: world.foreground, background: world.background)
        assertColors(fixture.sgr("38;2;255;1;32;48;2;0;64;255;"), foreground: world.foreground,
                     background: world.background)
    }

    func testMalformedColorsLeaveStylesIntactAndRecover() {
        let fixture = Fixture()
        let palette = fixture.world.palette
        _ = fixture.sgr("31;44;4")
        for malformed in ["38;2;0;1", "38;2;0;1;256", "38;2;0;-1;7", "48:2::1::3",
                          "48;5;99999999999999", "38;5", "38;3;0;1;7", "48:2:1:1:2:3"] {
            let output = fixture.sgr(malformed)
            XCTAssertEqual(output.string, "X", malformed)
            assertColors(output, foreground: palette[1], background: palette[4],
                         foregroundIndex: 1, backgroundIndex: 4)
            XCTAssertEqual(output.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int,
                           NSUnderlineStyle.single.rawValue, malformed)
        }

        let recoveryFixture = Fixture()
        _ = recoveryFixture.sgr("31;44")
        assertColors(recoveryFixture.sgr("?31"), foreground: palette[1], background: palette[4],
                     foregroundIndex: 1, backgroundIndex: 4)
        let recovered = recoveryFixture.input("\u{1B}[38;2;0;;256;32mA\u{1B}[48;2;4\u{1B}[48;2;4;5;6mB")
        XCTAssertEqual(recovered.string, "AB")
        assertColors(recovered, foreground: palette[2], background: palette[4],
                     foregroundIndex: 2, backgroundIndex: 4)
        assertColors(recovered, foreground: palette[2], background: rgb(4, 5, 6), foregroundIndex: 2, at: 1)
    }

    func testSplitRGBPromptReachesHostedSpawn() throws {
        let fixture = Fixture()
        let path = "ANSI Color Tests \(UUID())"
        let spawn = RDAtlantisSpawn(path: path, forInstance: fixture.world, withPrefs: nil)
        RDSpawnViewManager().selectView(spawn)
        defer {
            RDSpawnViewManager().removeView(spawn)
            UserDefaults.standard.removeObject(forKey: "RBSplitView H \(path)")
        }

        XCTAssertEqual(fixture.input("\u{1B}").string, "")
        XCTAssertEqual(fixture.input("[38;2;12;34").string, "")
        let prompt = fixture.input(";56;48:2::78:90:123mprompt> ")
        XCTAssertEqual(prompt.string, "prompt> ")
        spawn.appendString(prompt)
        let output = spawn.controller.outputView
        _ = output.commit()
        let storage = try XCTUnwrap(output.textStorage)
        let range = (storage.string as NSString).range(of: "prompt> ")
        XCTAssertNotEqual(range.location, NSNotFound)
        guard range.location != NSNotFound else { return }
        assertColors(storage, foreground: rgb(12, 34, 56), background: rgb(78, 90, 123), at: range.location)
    }

    func testTruecolorHTMLLogsInWebKit() async throws {
        let fixture = Fixture()
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let line = fixture.input(
            "\u{1B}[31;44mA\u{1B}[38;2;1;2;254mB\u{1B}[4mC"
            + "\u{1B}[48:2::254:128:0mD\u{1B}[7mE\u{1B}[39mF\u{1B}[27;0mG"
            + "\u{1B}[32;48;2;254;128;0mH\u{1B}[49mI\n"
        )
        for css in [true, false] {
            let url = directory.appendingPathComponent(css ? "stylesheet.html" : "inline.html")
            let log = try XCTUnwrap(RDHTMLLog(filename: url.path, forSpawn: nil, inWorld: fixture.world,
                                              withOptions: ["css": css, "cssFile": "colors.css"]))
            try writeLog(log, line: line, world: fixture.world)
            let html = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(html.contains("color: #0102FE;"))
            XCTAssertTrue(html.contains("background-color: #FE8000;"))
            if css {
                XCTAssertTrue(html.contains("class='bg04 ' style='color: #0102FE; '>B"))
                XCTAssertTrue(html.contains("class='bg04 ' style='color: #0102FE; '>C"))
                XCTAssertTrue(html.contains("class='fg02 ' style='background-color: #FE8000; '>H"))
                XCTAssertTrue(html.contains("class='fg02 '>I"))
            }

            let webView = WKWebView()
            webView.loadFileURL(url, allowingReadAccessTo: directory)
            let script = """
                (() => {
                    const row = [...document.querySelectorAll('div')].find(el => el.textContent === 'ABCDEFGHI');
                    if (!row || document.readyState !== 'complete') return null;
                    const walker = document.createTreeWalker(row, NodeFilter.SHOW_TEXT);
                    const colors = [];
                    while (walker.nextNode()) {
                        const style = getComputedStyle(walker.currentNode.parentElement);
                        for (const char of walker.currentNode.textContent) {
                            colors.push([char, style.color, style.backgroundColor]);
                        }
                    }
                    return colors;
                })()
                """
            var rendered: [[String]]?
            for _ in 0..<100 {
                if let colors = try? await webView.evaluateJavaScript(script) as? [[String]] {
                    rendered = colors
                    break
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            let colors = try XCTUnwrap(rendered, "WebKit did not render \(url.lastPathComponent)")
            XCTAssertEqual(colors.map { $0[0] }.joined(), "ABCDEFGHI")
            guard colors.count == 9 else { return }
            XCTAssertEqual(colors[1], ["B", "rgb(1, 2, 254)", colors[0][2]])
            XCTAssertEqual(colors[2], ["C", "rgb(1, 2, 254)", colors[0][2]])
            XCTAssertEqual(colors[3], ["D", "rgb(1, 2, 254)", "rgb(254, 128, 0)"])
            XCTAssertEqual(colors[4], ["E", "rgb(254, 128, 0)", "rgb(1, 2, 254)"])
            XCTAssertEqual(colors[5][1], "rgb(254, 128, 0)")
            XCTAssertNotEqual(colors[5][2], "rgb(1, 2, 254)")
            XCTAssertNotEqual(colors[6][1], "rgb(254, 128, 0)")
            XCTAssertEqual(colors[7][2], "rgb(254, 128, 0)")
            XCTAssertEqual(colors[8][1], colors[7][1])
            XCTAssertEqual(colors[8][2], colors[6][2])
            if css {
                XCTAssertNotEqual(colors[0][2], "rgba(0, 0, 0, 0)", "Palette stylesheet must load")
                XCTAssertEqual(colors[6][2], "rgba(0, 0, 0, 0)")
            }
        }
    }

    func testPlainAndFormattedLogsDiscardTruecolor() throws {
        let fixture = Fixture()
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let colored = fixture.input("\u{1B}[38;2;1;2;254;48;2;254;128;0mcolored text\u{1B}[0m\n")
        let plain = NSAttributedString(string: colored.string)

        for (index, line) in [colored, plain].enumerated() {
            let plainURL = directory.appendingPathComponent("plain-\(index).txt")
            let formattedURL = directory.appendingPathComponent("formatted-\(index).txt")
            let plainLog = try XCTUnwrap(RDPlainText(filename: plainURL.path, forSpawn: nil, inWorld: fixture.world))
            let formattedLog = try XCTUnwrap(RDFormattedText(filename: formattedURL.path, forSpawn: nil,
                inWorld: fixture.world, withOptions: ["wrap": false, "skiplines": false]))
            try writeLog(plainLog, line: line, world: fixture.world)
            try writeLog(formattedLog, line: line, world: fixture.world)
            for url in [plainURL, formattedURL] {
                let contents = try String(contentsOf: url, encoding: .utf8)
                XCTAssertTrue(contents.contains("colored text\n"))
                XCTAssertFalse(contents.contains("\u{1B}"))
                XCTAssertFalse(contents.contains("#0102FE"))
            }
        }
    }

    func testLogReplacementPublishesOnlyAfterPreparation() throws {
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("log.txt")
        let original = Data("original\n".utf8)
        try original.write(to: url)

        let logger = try XCTUnwrap(PreparedLogProbe(filename: url.path, forSpawn: nil, inWorld: nil))
        logger.prepare = { log in
            XCTAssertEqual(try? Data(contentsOf: url), original)
            log.writeString(toFile: "prepared\n")
            XCTAssertEqual(try? Data(contentsOf: url), original)
            return true
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        try logger.openFileForSavePanel(with: .replace, existingFile: attributes)
        XCTAssertEqual(try Data(contentsOf: url), Data("prepared\n".utf8))
        logger.writeString(toFile: "after publish\n")
        XCTAssertTrue(logger.closeFile())
        XCTAssertEqual(try Data(contentsOf: url), Data("prepared\nafter publish\n".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [url.lastPathComponent])
    }

    func testLogReplacementPreservesOriginalOnPreparationAndPublicationFailure() throws {
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("log.txt")
        let original = Data([0, 1, 2, 0xFF])
        try original.write(to: url)
        defer { _ = chflags(url.path, 0) }

        for failPublish in [false, true] {
            let logger = try XCTUnwrap(PreparedLogProbe(filename: url.path, forSpawn: nil, inWorld: nil))
            logger.prepare = { log in
                log.writeString(toFile: "partial replacement")
                if failPublish {
                    XCTAssertEqual(chflags(url.path, UInt32(UF_IMMUTABLE)), 0)
                }
                return failPublish
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertThrowsError(try logger.openFileForSavePanel(with: .replace, existingFile: attributes))
            XCTAssertFalse(logger.isOpen())
            XCTAssertEqual(try Data(contentsOf: url), original)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [url.lastPathComponent])
            XCTAssertEqual(chflags(url.path, 0), 0)
        }
    }

    func testLogSavePreservesAFileThatAppearsOrChangesDuringPreparation() throws {
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("log.txt")
        let intervening = Data("changed by another writer".utf8)

        for mode in [RDLogSaveMode.create, .replace] {
            let attributes: [FileAttributeKey: Any]?
            if mode == .replace {
                try Data("old".utf8).write(to: url)
                attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            } else {
                attributes = nil
            }
            let logger = try XCTUnwrap(PreparedLogProbe(filename: url.path, forSpawn: nil, inWorld: nil))
            logger.prepare = { _ in
                do {
                    try intervening.write(to: url, options: .atomic)
                    return true
                } catch {
                    XCTFail("Could not update the destination: \(error)")
                    return false
                }
            }
            XCTAssertThrowsError(try logger.openFileForSavePanel(with: mode, existingFile: attributes))
            XCTAssertEqual(try Data(contentsOf: url), intervening)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [url.lastPathComponent])
        }
    }

    func testLogCreatePublishesPreparedBytesAtNewDestination() throws {
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("log.txt")
        let logger = try XCTUnwrap(PreparedLogProbe(filename: url.path, forSpawn: nil, inWorld: nil))
        logger.prepare = { log in
            log.writeString(toFile: "new log")
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            return true
        }
        try logger.openFileForSavePanel(with: .create, existingFile: nil)
        XCTAssertTrue(logger.closeFile())
        XCTAssertEqual(try Data(contentsOf: url), Data("new log".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [url.lastPathComponent])
    }

    func testLogPreparationDoesNotRemoveAnUnrelatedFileAtTheStagingName() throws {
        let manager = FileManager.default
        let directory = try temporaryLogDirectory()
        defer { try? manager.removeItem(at: directory) }
        let url = directory.appendingPathComponent("log.txt")
        let original = Data("original".utf8)
        let unrelated = Data("unrelated".utf8)
        try original.write(to: url)
        var reusedStagingURL: URL?
        let logger = try XCTUnwrap(PreparedLogProbe(filename: url.path, forSpawn: nil, inWorld: nil))
        logger.prepare = { _ in
            do {
                let names = try manager.contentsOfDirectory(atPath: directory.path)
                let stagingName = try XCTUnwrap(names.first { $0.hasPrefix(".atlantis-log.") })
                let stagingURL = directory.appendingPathComponent(stagingName)
                try manager.moveItem(at: stagingURL, to: directory.appendingPathComponent("moved-stage"))
                try unrelated.write(to: stagingURL)
                reusedStagingURL = stagingURL
            } catch {
                XCTFail("Could not reuse the staging name: \(error)")
            }
            return false
        }
        let attributes = try manager.attributesOfItem(atPath: url.path)
        XCTAssertThrowsError(try logger.openFileForSavePanel(with: .replace, existingFile: attributes))
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reusedStagingURL)), unrelated)
    }

    func testLogAppendKeepsExistingBytesAndRequiresExistingFile() throws {
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("log.txt")
        let original = Data([0, 1, 0xFF])
        try original.write(to: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let logger = try XCTUnwrap(RDPlainText(filename: url.path, forSpawn: nil, inWorld: nil))
        try logger.openFileForSavePanel(with: .append, existingFile: attributes)
        logger.writeString(toFile: "appended")
        XCTAssertTrue(logger.closeFile())
        XCTAssertEqual(try Data(contentsOf: url), original + Data("appended".utf8))
        try FileManager.default.removeItem(at: url)
        XCTAssertThrowsError(try logger.openFileForSavePanel(with: .append, existingFile: attributes))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSavePanelDoesNotReplaceOrAppendToAnActiveLog() throws {
        let directory = try temporaryLogDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("log.txt")
        let original = Data("active log".utf8)
        try original.write(to: url)
        let active = try XCTUnwrap(RDPlainText(filename: url.path, forSpawn: nil, inWorld: nil))
        let proposed = try XCTUnwrap(RDPlainText(filename: url.path, forSpawn: nil, inWorld: nil))
        XCTAssertTrue(active.openFile())
        defer { _ = active.closeFile() }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        for mode in [RDLogSaveMode.replace, .append] {
            XCTAssertThrowsError(try proposed.openFileForSavePanel(with: mode, existingFile: attributes))
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
        active.writeString(toFile: " stays writable")
        XCTAssertEqual(try Data(contentsOf: url), original + Data(" stays writable".utf8))
    }

    private func temporaryLogDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeLog(_ log: RDLogType, line: NSAttributedString, world: ColorTestWorld) throws {
        guard log.openFile() else {
            throw CocoaError(.fileWriteUnknown)
        }
        let state = AtlantisState(string: nil, inWorld: world, for: nil)
        log.write(line, with: state)
        XCTAssertTrue(log.closeFile())
    }

    private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }

    private func assertColors(
        _ output: NSAttributedString, foreground: NSColor, background: NSColor,
        foregroundIndex: Int? = nil, backgroundIndex: Int? = nil,
        at index: Int = 0, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard output.length > index else {
            XCTFail("Missing attributed output", file: file, line: line)
            return
        }
        let attributes = output.attributes(at: index, effectiveRange: nil)
        for (key, expected) in [(NSAttributedString.Key.foregroundColor, foreground), (.backgroundColor, background)] {
            guard let actual = (attributes[key] as? NSColor)?.usingColorSpace(.sRGB),
                  let expected = expected.usingColorSpace(.sRGB) else {
                XCTFail("Missing RGB color for \(key)", file: file, line: line)
                continue
            }
            XCTAssertEqual(actual.redComponent, expected.redComponent, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(actual.greenComponent, expected.greenComponent, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(actual.blueComponent, expected.blueComponent, accuracy: 0.0001, file: file, line: line)
        }
        XCTAssertEqual(attributes[.init("RDAnsiForegroundColor")] as? Int, foregroundIndex, file: file, line: line)
        XCTAssertEqual(attributes[.init("RDAnsiBackgroundColor")] as? Int, backgroundIndex, file: file, line: line)
    }

    private final class Fixture {
        let world = ColorTestWorld()
        lazy var filter = RDAnsiFilter(world: world)!

        func input(_ text: String) -> NSAttributedString {
            let output = NSMutableAttributedString(string: text)
            filter.filterInput(output)
            return output
        }

        func sgr(_ parameters: String) -> NSAttributedString {
            input("\u{1B}[\(parameters)mX")
        }
    }
}

private final class ColorTestWorld: RDAtlantisWorldInstance {
    var telnetReplies: [Data] = []
    var storedWorldPreferences: RDAtlantisWorldPreferences?
    weak var promptSpawn: RDAtlantisSpawn?

    override func preferences() -> RDAtlantisWorldPreferences! { storedWorldPreferences }
    override func mainSpawn() -> RDAtlantisSpawn! { promptSpawn }

    override func sendDataRaw(_ data: Data!) {
        telnetReplies.append(data)
    }

    let foreground = NSColor(srgbRed: 0.8, green: 0.7, blue: 0.6, alpha: 1)
    let background = NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 1)
    let palette = (0..<16).map { NSColor(srgbRed: CGFloat($0) / 16, green: 0.4, blue: 0.6, alpha: 1) }

    override func displayFont() -> NSFont! { .monospacedSystemFont(ofSize: 12, weight: .regular) }
    override func paragraphStyle() -> NSParagraphStyle! { .default }
    override func baseStateInfo() -> [AnyHashable: Any]! { ["world.name": "Color Test"] }
    override func outputStatus(_ string: String!, toSpawn spawnPath: String!) {}
    override func closeAndRemove() {}


    override func preference(forKey key: String!) -> Any! {
        switch key {
        case "atlantis.colors.ansi": return palette
        case "atlantis.colors.default": return foreground
        case "atlantis.colors.background": return background
        case "atlantis.formatting.boldIntense": return true
        case "atlantis.network.keepalive": return 3
        default: return nil
        }
    }
}


private final class PreparedLogProbe: RDPlainText {
    var prepare: ((PreparedLogProbe) -> Bool)?

    override func openFile() -> Bool {
        super.openFile() && (prepare?(self) ?? true)
    }
}
