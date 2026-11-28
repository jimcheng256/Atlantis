import AppKit
import ObjectiveC.runtime
import SwiftUI
import XCTest
@testable import Atlantis

final class RDAtlantisSpawnTests: XCTestCase {
    @MainActor
    func testBackgroundSpawnActivityUpdatesApplicationDockBadge() throws {
        let controller = try XCTUnwrap(RDPreferenceMainController())
        let manager = RDSpawnViewManager()
        let dockTile = NSApplication.shared.dockTile
        let defaults = UserDefaults.standard
        let domain = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let keys = ["atlantis.badge.inactive", "atlantis.badge.visible"]
        let previous = defaults.persistentDomain(forName: domain) ?? [:]
        for key in keys { defaults.set(false, forKey: key) }
        defer {
            for key in keys {
                if let value = previous[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
            controller.refreshBadge()
        }

        try withSpawn { background, _ in
            try withSpawn { _, _ in
                let baseline = try XCTUnwrap(manager.activeViews()).count
                controller.refreshBadge()
                XCTAssertEqual(dockTile.badgeLabel, baseline == 0 ? nil : String(baseline))
                defer { manager.view(background, hasActivity: false) }

                manager.view(background, hasActivity: true)
                XCTAssertEqual(dockTile.badgeLabel, String(baseline + 1))

                manager.view(background, hasActivity: true)
                XCTAssertEqual(dockTile.badgeLabel, String(baseline + 1))

                manager.view(background, hasActivity: false)
                XCTAssertEqual(dockTile.badgeLabel, baseline == 0 ? nil : String(baseline))
            }
        }
    }

    @MainActor
    func testHostedTerminalWiresLegacyTextViewsAndSelectors() throws {
        try withSpawn { spawn, world in
            XCTAssertTrue(NSClassFromString("RDAtlantisSpawn") == type(of: spawn))
            XCTAssertTrue(spawn.responds(to: NSSelectorFromString("initWithPath:forInstance:withPrefs:")))
            XCTAssertTrue(spawn.responds(to: NSSelectorFromString("textView:committedInput:")))
            XCTAssertTrue(spawn.responds(to: NSSelectorFromString("shouldShowTooltipFor:")))

            let split = spawn.controller.splitView
            XCTAssertTrue(spawn.view() is NSHostingView<SpawnView>)
            XCTAssertTrue(split.isDescendant(of: spawn.view()))
            XCTAssertEqual(split.subviews.count, 2)
            XCTAssertEqual(split.dividerThickness(), 8)
            let output = spawn.controller.outputView
            let input = spawn.controller.inputView
            XCTAssertTrue(output.enclosingScrollView is RDScrollView)
            XCTAssertTrue(output.enclosingScrollView?.verticalScroller is RDScroller)
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
            let host = try XCTUnwrap(spawn.view())
            let split = spawn.controller.splitView
            @MainActor func margins() -> (top: CGFloat, bottom: CGFloat) {
                let frame = split.convert(split.bounds, to: host)
                let low = frame.minY - host.bounds.minY
                let high = host.bounds.maxY - frame.maxY
                return host.isFlipped ? (low, high) : (high, low)
            }

            spawn.setStatusBarHidden(false)
            spawn.setStatusBarBottom(false)
            XCTAssertTrue(waitForLayout(of: host) { abs(margins().top - 21) <= 1 && abs(margins().bottom) <= 1 })

            spawn.setStatusBarHidden(true)
            spawn.setStatusBarBottom(true)
            XCTAssertTrue(waitForLayout(of: host) { abs(margins().top) <= 1 && abs(margins().bottom) <= 1 })

            spawn.setStatusBarHidden(false)
            XCTAssertTrue(waitForLayout(of: host) { abs(margins().bottom - 21) <= 1 && abs(margins().top) <= 1 })

            let text = NSAttributedString(string: "Ready", attributes: [.foregroundColor: NSColor.red])
            spawn.setStatusBarUserText(text)
            XCTAssertTrue(waitForLayout(of: host) {
                self.statusMessageField(in: host)?.attributedStringValue.isEqual(to: text) == true
            })
            XCTAssertEqual(spawn.statusBarUserText(), "Ready")
            XCTAssertGreaterThan(spawn.screenWidth(), 0)
            XCTAssertGreaterThan(spawn.screenHeight(), 0)
            XCTAssertTrue(waitForLayout(of: host) {
                spawn.controller.status.tooltip.contains("\(spawn.screenWidth())x\(spawn.screenHeight()) screen size")
            })
        }
    }

    @MainActor
    func testEditorsRouteTypingAndScrolling() throws {
        try withSpawn { spawn, _ in
            let input = spawn.controller.inputView
            let output = spawn.controller.outputView
            spawn.stringIntoInput("")
            _ = output.perform(NSSelectorFromString("insertText:"), with: "draft")
            XCTAssertEqual(spawn.stringFromInput(), "draft")
            XCTAssertTrue(input.window?.firstResponder === input)

            spawn.appendStringNoTimestamp(NSAttributedString(string: String(repeating: "scrollback line\n", count: 300)))
            _ = output.commit()
            let clip = try XCTUnwrap(output.enclosingScrollView?.contentView)
            output.scrollToEndOfDocument(nil)
            XCTAssertGreaterThan(clip.bounds.minY, 0)
            input.doCommand(by: #selector(NSResponder.scrollToBeginningOfDocument(_:)))
            XCTAssertEqual(clip.bounds.minY, 0, accuracy: 1)
        }
    }

    @MainActor
    func testEditorsKeepDraftSelectionAndScrollbackAcrossUpdatesAndWindowMove() throws {
        try withSpawn { spawn, _ in
            let host = try XCTUnwrap(spawn.view())
            let input = spawn.controller.inputView
            let output = spawn.controller.outputView
            let previousSuperview = try XCTUnwrap(host.superview)
            let previousFrame = host.frame
            let secondWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                                        styleMask: [.titled], backing: .buffered, defer: false)
            defer {
                secondWindow.contentView = nil
                previousSuperview.addSubview(host)
                host.frame = previousFrame
            }

            spawn.stringIntoInput("draft")
            input.setSelectedRange(NSRange(location: 1, length: 3))
            spawn.appendString(NSAttributedString(string: "received text"))
            _ = output.commit()
            output.setSelectedRange(NSRange(location: 0, length: 8))

            spawn.setStatusBarHidden(false)
            spawn.setStatusBarBottom(true)
            spawn.setStatusBarUserText(NSAttributedString(string: "Connected"))
            XCTAssertTrue(waitForLayout(of: host) { self.statusMessageField(in: host)?.stringValue == "Connected" })

            host.removeFromSuperview()
            secondWindow.contentView = host
            XCTAssertTrue(waitForLayout(of: host) { input.window === secondWindow && output.window === secondWindow })
            XCTAssertTrue(spawn.view() === host)
            XCTAssertTrue(spawn.controller.inputView === input)
            XCTAssertTrue(spawn.controller.outputView === output)
            XCTAssertEqual(spawn.stringFromInput(), "draft")
            XCTAssertEqual(spawn.stringFromInputSelection(), "raf")
            XCTAssertEqual(output.string, "received text")
            XCTAssertEqual(spawn.stringFromOutputSelection(), "received")
        }
    }

    @MainActor
    func testInputAndOutputRoundTrip() throws {
        try withSpawn { spawn, _ in
            let input = spawn.controller.inputView
            let output = spawn.controller.outputView
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
            let input = spawn.controller.inputView
            spawn.setPrefix("radio")
            spawn.stringIntoInput("hello")
            let firstContext = inputCommitContext(input)
            input.insertNewline(nil)
            XCTAssertEqual(world.committedInput, "radio hello", firstContext)

            spawn.stringIntoInput("radio already prefixed")
            let secondContext = inputCommitContext(input)
            input.insertNewline(nil)
            XCTAssertEqual(world.committedInput, "radio already prefixed", secondContext)
        }
    }

    @MainActor
    func testEnterSubmissionDependsOnCurrentEventAndDelegate() throws {
        for (flags, removeDelegate, shouldSubmit) in [
            (NSEvent.ModifierFlags(), false, true),
            (.shift, false, false),
            ([], true, false),
        ] {
            try withSpawn { spawn, world in
                let input = spawn.controller.inputView
                let delegate = try XCTUnwrap(input.delegate)
                XCTAssertTrue(delegate === spawn)
                if removeDelegate {
                    input.delegate = nil
                }
                defer { input.delegate = delegate }

                let event = try XCTUnwrap(NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                    windowNumber: input.window?.windowNumber ?? 0,
                    context: nil, characters: "x", charactersIgnoringModifiers: "x",
                    isARepeat: false, keyCode: 7))
                let getter = try XCTUnwrap(class_getInstanceMethod(
                    type(of: NSApp!), #selector(getter: NSApplication.currentEvent)))
                let currentEvent: @convention(block) (NSApplication) -> NSEvent = { _ in event }
                let replacement = imp_implementationWithBlock(currentEvent)
                let original = method_setImplementation(getter, replacement)
                defer {
                    method_setImplementation(getter, original)
                    imp_removeBlock(replacement)
                }

                spawn.setPrefix("radio")
                spawn.stringIntoInput("hello")
                input.insertNewline(nil)
                XCTAssertEqual(world.committedInput, shouldSubmit ? "radio hello" : nil)
                if !shouldSubmit {
                    XCTAssertEqual(input.string.filter { $0 == "\n" }.count, 1)
                }
            }
        }
    }

    @MainActor
    private func inputCommitContext(_ input: NSTextView) -> String {
        let event = NSApp.currentEvent
        let type = event.map { String($0.type.rawValue) } ?? "none"
        let modifiers = event.map { String($0.modifierFlags.rawValue, radix: 16) } ?? "none"
        let delegate = input.delegate.map { String(describing: Swift.type(of: $0)) } ?? "none"
        return "Current event type \(type), modifier flags 0x\(modifiers), input delegate \(delegate)"
    }

    @MainActor
    func testTimestampAppliesOnlyAtLineStartAndPreservesAttributes() throws {
        let world = TestWorld()
        world.showTimestamps = true
        try withSpawn(world: world) { spawn, _ in
            let output = spawn.controller.outputView
            let marker = NSAttributedString.Key("RDOmitSpan")
            spawn.appendString(NSAttributedString(string: "first", attributes: [.foregroundColor: NSColor.red]))
            spawn.appendString(NSAttributedString(string: " continuation\n"))
            spawn.appendString(NSAttributedString(string: "second"))
            _ = output.commit()

            let storage = try XCTUnwrap(output.textStorage)
            let lines = storage.string.components(separatedBy: "\n")
            XCTAssertEqual(lines.count, 2)
            XCTAssertEqual(lines.first?.dropFirst(11), "first continuation")
            XCTAssertEqual(lines.last?.dropFirst(11), "second")
            XCTAssertEqual(storage.attribute(marker, at: 0, effectiveRange: nil) as? Bool, true)
            XCTAssertEqual(storage.attribute(.foregroundColor, at: 11, effectiveRange: nil) as? NSColor, .red)
        }
    }

    @MainActor
    func testSplitRestoresProportionsForSpawnPath() throws {
        let path = "Spawn Tests \(UUID())"
        defer { UserDefaults.standard.removeObject(forKey: "RBSplitView H \(path)") }
        var savedProportion: CGFloat = 0
        try withSpawn(path: path) { spawn, _ in
            spawn.setStatusBarHidden(false)
            let split = spawn.controller.splitView
            let inputPane = try XCTUnwrap(split.subviews.last as? RBSplitSubview)
            let initialHeight = inputPane.frame.height
            inputPane.setDimension(110)
            savedProportion = inputPane.frame.height / (split.bounds.height - split.dividerThickness())
            XCTAssertNotEqual(initialHeight, inputPane.frame.height)
            XCTAssertTrue(split.saveState(false))
        }

        try withSpawn(path: path) { spawn, _ in
            spawn.setStatusBarHidden(false)
            let split = spawn.controller.splitView
            let inputPane = try XCTUnwrap(split.subviews.last)
            let restoredProportion = inputPane.frame.height / (split.bounds.height - split.dividerThickness())
            XCTAssertEqual(restoredProportion, savedProportion, accuracy: 0.01)
        }
    }

    @MainActor
    private func statusMessageField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.accessibilityIdentifier() == "spawn-status-message" {
            return field
        }
        for subview in view.subviews {
            if let field = statusMessageField(in: subview) { return field }
        }
        return nil
    }

    @MainActor
    private func waitForLayout(of host: NSView, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(1)
        repeat {
            host.layoutSubtreeIfNeeded()
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while Date() < deadline
        return false
    }

    @MainActor
    private func withSpawn(
        path specifiedPath: String? = nil,
        world: TestWorld = TestWorld(),
        _ body: (RDAtlantisSpawn, TestWorld) throws -> Void
    ) throws {
        let path = specifiedPath ?? "Spawn Tests \(UUID())"
        let spawn = RDAtlantisSpawn(path: path, forInstance: world, withPrefs: nil)
        RDSpawnViewManager().selectView(spawn)
        spawn.view().layoutSubtreeIfNeeded()
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
    var showTimestamps = false

    override func preference(forKey key: String!) -> Any! {
        key == "atlantis.formatting.timestamps" ? NSNumber(value: showTimestamps) : nil
    }

    override func handleLocalInput(_ input: NSAttributedString!, on spawn: RDAtlantisSpawn!) {
        committedInput = input?.string
    }

    override func stringEncoding() -> UInt { UInt.max }

    override func closeAndRemove() {}
}
