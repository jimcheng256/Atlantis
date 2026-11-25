import SwiftUI

struct SpawnView: View {
    @ObservedObject var controller: SpawnController

    var body: some View {
        let status = controller.status
        SpawnTerminalView(splitView: controller.splitView)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(status.atBottom ? .bottom : .top, status.hidden ? 0 : 21)
            .overlay(alignment: status.atBottom ? .bottom : .top) {
                if !status.hidden {
                    statusBar(status)
                }
            }
    }

    private func statusBar(_ status: SpawnStatus) -> some View {
        HStack(spacing: 3) {
            SpawnStatusMessage(text: status.message)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let separator = NSImage(named: "StatusSep") {
                Image(nsImage: separator).accessibilityHidden(true)
            }
            Text(status.timer)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(nsColor: .controlTextColor))
                .frame(width: 61)
            if let lock = NSImage(named: status.usesSSL ? "statusLockedSelected" : "statusLocked") {
                Image(nsImage: lock)
                    .accessibilityLabel(status.usesSSL ? "SSL encryption enabled" : "SSL encryption disabled")
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 21)
        .background {
            if let background = NSImage(named: "StatusBarBackground") {
                GeometryReader { geometry in
                    Image(nsImage: background)
                        .resizable(resizingMode: .tile)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .accessibilityHidden(true)
            }
        }
        .help(status.tooltip)
    }
}

private struct SpawnTerminalView: NSViewRepresentable {
    let splitView: RBSplitView

    func makeNSView(context: Context) -> RBSplitView { splitView }
    func updateNSView(_ view: RBSplitView, context: Context) {}
}

// Preserve the Cocoa attributes that callers supply to setStatusBarUserText:.
private struct SpawnStatusMessage: NSViewRepresentable {
    let text: NSAttributedString

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: 11)
        field.lineBreakMode = .byTruncatingTail
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.attributedStringValue = text
        field.setAccessibilityIdentifier("spawn-status-message")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if !field.attributedStringValue.isEqual(to: text) {
            field.attributedStringValue = text
        }
    }
}
