import AppKit
import XCTest
@testable import Atlantis

final class RDAtlantisSpawnTests: XCTestCase {
    @MainActor
    func testCompiledNibWiresLegacyTextViewsAndSelectors() throws {
        try withSpawn { spawn, world in
            XCTAssertTrue(NSClassFromString("RDAtlantisSpawn") == type(of: spawn))
            XCTAssertTrue(spawn.responds(to: NSSelectorFromString("initWithPath:forInstance:withPrefs:")))
            XCTAssertTrue(spawn.responds(to: NSSelectorFromString("textView:committedInput:")))
            XCTAssertTrue(spawn.responds(to: NSSelectorFromString("shouldShowTooltipFor:")))

            let split = try XCTUnwrap(spawn.view().subviews.compactMap { $0 as? RBSplitView }.first)
            XCTAssertEqual(split.subviews.count, 2)
            XCTAssertEqual(split.dividerThickness(), 8)
            let output = try XCTUnwrap(spawn.value(forKey: "outputView") as? RDTextView)
            let input = try XCTUnwrap(spawn.value(forKey: "inputView") as? RDAtlantisTextInputView)
            XCTAssertTrue(output.enclosingScrollView is RDScrollView)
            XCTAssertTrue(input.delegate === spawn)
            XCTAssertTrue(input.value(forKey: "passInputsTo") as AnyObject? === output)
            XCTAssertTrue(output.value(forKey: "_rdRedirectFocusOnKeyTo") as AnyObject? === input)
            XCTAssertFalse(output.isEditable)
            XCTAssertTrue(input.isEditable)
            XCTAssertTrue(spawn.world() === world)
            XCTAssertTrue((output.enclosingScrollView?.documentView) === output)
            XCTAssertTrue((input.enclosingScrollView?.documentView) === input)
        }
    }

    @MainActor
    func testSplitAndStatusBarFollowVisibilityAndPlacement() throws {
        try withSpawn { spawn, _ in
            let content = try XCTUnwrap(spawn.view())
            let split = try XCTUnwrap(content.subviews.compactMap { $0 as? RBSplitView }.first)
            let status = try XCTUnwrap(content.subviews.compactMap { $0 as? ImageBackgroundView }.first)
            spawn.setStatusBarHidden(false)
            spawn.setStatusBarBottom(false)
            XCTAssertEqual(split.frame.maxY, status.frame.minY, accuracy: 1)

            spawn.setStatusBarHidden(true)
            spawn.setStatusBarBottom(true)
            XCTAssertTrue(status.isHidden)
            XCTAssertEqual(split.frame, content.bounds)

            spawn.setStatusBarHidden(false)
            XCTAssertFalse(status.isHidden)
            XCTAssertEqual(status.frame.minY, 0)
            XCTAssertEqual(split.frame.minY, status.frame.maxY, accuracy: 1)
            content.setFrameSize(NSSize(width: 780, height: 520))
            XCTAssertEqual(split.frame.maxY, content.bounds.maxY, accuracy: 1)

            spawn.setStatusBarUserText(NSAttributedString(string: "Ready"))
            XCTAssertEqual(spawn.statusBarUserText(), "Ready")
            XCTAssertGreaterThan(spawn.screenWidth(), 0)
            XCTAssertGreaterThan(spawn.screenHeight(), 0)
        }
    }

    @MainActor
    func testInputAndOutputRoundTrip() throws {
        try withSpawn { spawn, _ in
            let input = try XCTUnwrap(spawn.value(forKey: "inputView") as? NSTextView)
            let output = try XCTUnwrap(spawn.value(forKey: "outputView") as? RDTextView)
            spawn.stringIntoInput("say hello")
            input.setSelectedRange(NSRange(location: 4, length: 5))
            XCTAssertEqual(spawn.stringFromInputSelection(), "hello")
            spawn.stringInsertIntoInput("world")
            XCTAssertEqual(spawn.stringFromInput(), "say world")

            let omitted = NSAttributedString(string: "skip", attributes: [
                NSAttributedString.Key("RDScreenOmitLine"): true
            ])
            spawn.appendString(omitted)
            spawn.appendString(NSAttributedString(string: "first"))
            spawn.ensureNewline()
            spawn.ensureNewline()
            spawn.appendStringNoTimestamp(NSAttributedString(string: "second"))
            _ = output.commit()
            XCTAssertEqual(output.string, "first\nsecond")
            XCTAssertFalse(spawn.scrollbackData().isEmpty)
            output.setSelectedRange(NSRange(location: 6, length: 6))
            XCTAssertEqual(spawn.stringFromOutputSelection(), "second")
            spawn.clearScrollback()
            XCTAssertEqual(output.string, "")
        }
    }

    @MainActor
    func testCommittedInputAddsPrefixOnce() throws {
        try withSpawn { spawn, world in
            let input = try XCTUnwrap(spawn.value(forKey: "inputView") as? NSTextView)
            spawn.setPrefix("radio")
            spawn.stringIntoInput("hello")
            input.insertNewline(nil)
            XCTAssertEqual(world.committedInput, "radio hello")

            spawn.stringIntoInput("radio already prefixed")
            input.insertNewline(nil)
            XCTAssertEqual(world.committedInput, "radio already prefixed")
        }
    }

    @MainActor
    func testSplitRestoresProportionsForSpawnPath() throws {
        let path = "Spawn Tests \(UUID())"
        defer { UserDefaults.standard.removeObject(forKey: "RBSplitView H \(path)") }
        var savedProportion: CGFloat = 0
        try withSpawn(path: path) { spawn, _ in
            spawn.setStatusBarHidden(false)
            let split = try XCTUnwrap(spawn.view().subviews.compactMap { $0 as? RBSplitView }.first)
            let inputPane = try XCTUnwrap(split.subviews.last as? RBSplitSubview)
            let initialHeight = inputPane.frame.height
            inputPane.setDimension(110)
            savedProportion = inputPane.frame.height / (split.bounds.height - split.dividerThickness())
            XCTAssertNotEqual(initialHeight, inputPane.frame.height)
            XCTAssertTrue(split.saveState(false))
        }

        try withSpawn(path: path) { spawn, _ in
            spawn.setStatusBarHidden(false)
            let split = try XCTUnwrap(spawn.view().subviews.compactMap { $0 as? RBSplitView }.first)
            let inputPane = try XCTUnwrap(split.subviews.last)
            let restoredProportion = inputPane.frame.height / (split.bounds.height - split.dividerThickness())
            XCTAssertEqual(restoredProportion, savedProportion, accuracy: 0.01)
        }
    }

    @MainActor
    private func withSpawn(
        path specifiedPath: String? = nil,
        _ body: (RDAtlantisSpawn, TestWorld) throws -> Void
    ) throws {
        let path = specifiedPath ?? "Spawn Tests \(UUID())"
        let world = TestWorld()
        let spawn = RDAtlantisSpawn(path: path, forInstance: world, withPrefs: nil)
        defer {
            RDSpawnViewManager().removeView(spawn)
            if specifiedPath == nil { UserDefaults.standard.removeObject(forKey: "RBSplitView H \(path)") }
        }
        XCTAssertEqual(spawn.viewPath(), path)
        XCTAssertEqual(spawn.viewName(), path)
        XCTAssertEqual(spawn.viewUID(), "Atlantis.spawn:\(path)")
        try body(spawn, world)
    }
}

private final class TestWorld: RDAtlantisWorldInstance {
    private(set) var committedInput: String?

    override func handleLocalInput(_ input: NSAttributedString!, on spawn: RDAtlantisSpawn!) {
        committedInput = input?.string
    }

    override func stringEncoding() -> UInt { UInt.max }

    override func closeAndRemove() {}
}
