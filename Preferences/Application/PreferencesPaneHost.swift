import AppKit
import SwiftUI

struct PreferencesPaneHost: NSViewRepresentable {
    let paneView: NSView

    func makeNSView(context: Context) -> PaneContainer {
        PaneContainer(paneView: paneView)
    }

    func updateNSView(_ nsView: PaneContainer, context: Context) {}

    final class PaneContainer: NSView {
        private let paneView: NSView

        init(paneView: NSView) {
            self.paneView = paneView
            super.init(frame: NSRect(origin: .zero, size: paneView.frame.size))
            addSubview(paneView)
            paneView.frame = bounds
        }

        required init?(coder: NSCoder) {
            fatalError("Preferences panes are hosted programmatically")
        }

        override func resizeSubviews(withOldSize oldSize: NSSize) {
            // The pane used to be the window content view and filled it on resize.
            paneView.frame = bounds
        }
    }
}
