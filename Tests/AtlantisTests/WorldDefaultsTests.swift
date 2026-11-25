import AppKit
import XCTest
@testable import Atlantis

final class WorldDefaultsTests: XCTestCase {
    @MainActor
    func testGlobalEditorKeepsSharedTabsInTheirOriginalOrder() throws {
        let pane = WorldDefaults()
        let view = try XCTUnwrap(pane.preferencePaneView() as? NSTabView)
        XCTAssertEqual(view.tabViewItems.map(\.label), ["Formatting", "Highlights", "Spawns", "Events", "Aliases", "User Variables"])
        XCTAssertEqual(view.frame.size, NSSize(width: 900, height: 700))
        view.selectTabViewItem(at: 1)
        XCTAssertTrue(view === pane.preferencePaneView())
        XCTAssertEqual(view.selectedTabViewItem?.label, "Highlights")
    }

    @MainActor
    func testPaneCommitsTheEditorAndReusesItsNativeView() {
        let editor = RecordingWorldEditor(view: NSTabView(frame: .zero))
        let pane = WorldDefaults(editor: editor)
        XCTAssertTrue(pane.preferencePaneView() === editor.view)
        XCTAssertEqual(editor.commits, 0)
        pane.preferencePaneCommit()
        XCTAssertEqual(editor.commits, 1)
    }
}

private final class RecordingWorldEditor: WorldConfigurationEditor {
    let view: NSView
    var commits = 0

    init(view: NSView) {
        self.view = view
        super.init()
    }

    override func configView() -> NSView! { view }
    override func commitAll() { commits += 1 }
}
