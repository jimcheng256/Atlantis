import AppKit
import XCTest
@testable import Atlantis

@MainActor
final class ANSIColorTests: XCTestCase {
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
    let foreground = NSColor(srgbRed: 0.8, green: 0.7, blue: 0.6, alpha: 1)
    let background = NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 1)
    let palette = (0..<16).map { NSColor(srgbRed: CGFloat($0) / 16, green: 0.4, blue: 0.6, alpha: 1) }

    override func paragraphStyle() -> NSParagraphStyle! { .default }
    override func closeAndRemove() {}


    override func preference(forKey key: String!) -> Any! {
        switch key {
        case "atlantis.colors.ansi": return palette
        case "atlantis.colors.default": return foreground
        case "atlantis.colors.background": return background
        case "atlantis.formatting.boldIntense": return true
        default: return nil
        }
    }
}
