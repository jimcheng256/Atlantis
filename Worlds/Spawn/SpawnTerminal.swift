import AppKit

@MainActor
final class SpawnTerminal {
    let splitView: RBSplitView
    let inputView: RDAtlantisTextInputView
    let outputView: RDTextView

    init() {
        let frame = NSRect(x: 0, y: 0, width: 617, height: 412)
        guard let split = RBSplitView(frame: frame) else {
            preconditionFailure("Could not create the spawn split view")
        }

        let outputFrame = NSRect(x: 0, y: 0, width: frame.width, height: 350)
        let inputFrame = NSRect(x: 0, y: 0, width: frame.width, height: 55)
        guard let outputScroll = RDScrollView(frame: outputFrame) else {
            preconditionFailure("Could not create the spawn output scroller")
        }
        let inputScroll = NSScrollView(frame: inputFrame)
        let output = RDTextView(frame: outputFrame)
        let input = RDAtlantisTextInputView(frame: inputFrame)
        Self.configure(outputScroll, document: output, minimumHeight: 0)
        Self.configure(inputScroll, document: input, minimumHeight: 46)
        output.isEditable = false
        input.allowsUndo = true
        RDSpawnSetEditorRouting(input, output, true)

        split.setVertical(false)
        split.addSubview(outputScroll)
        split.addSubview(inputScroll)
        RDSpawnConfigureDivider(split, NSImage(named: "spawn-dimple"),
                                NSImage(named: "spawn-splitter")?.copy() as? NSImage)
        split.adjustSubviews()
        self.splitView = split
        self.inputView = input
        self.outputView = output
    }

    private static func configure(_ scroll: NSScrollView, document: NSTextView, minimumHeight: CGFloat) {
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        let width = scroll.contentSize.width
        document.frame = NSRect(x: 0, y: 0, width: width, height: scroll.contentSize.height)
        document.minSize = NSSize(width: 114, height: minimumHeight)
        document.maxSize = NSSize(width: 10_000_000, height: 10_000_000)
        document.autoresizingMask = .width
        document.isVerticallyResizable = true
        document.isHorizontallyResizable = false
        document.importsGraphics = false
        document.textContainer?.widthTracksTextView = true
        document.textContainer?.containerSize = NSSize(width: width, height: 10_000_000)
        scroll.documentView = document
    }
}
