import AppKit

@MainActor
@objc(WorldDefaults)
final class WorldDefaults: NSObject, @preconcurrency AtlantisPreferencePane {
    private let editor: WorldConfigurationEditor

    override convenience init() {
        self.init(editor: RDCreateGlobalWorldConfigurationEditor())
    }

    init(editor: WorldConfigurationEditor) {
        self.editor = editor
        super.init()
        editor.configView().frame = NSRect(x: 0, y: 0, width: 900, height: 700)
    }

    @objc func preferencePaneName() -> String! { "World Defaults" }
    @objc func preferencePaneImage() -> NSImage! { NSImage(named: "connect") }
    @objc func preferencePaneView() -> NSView! { editor.configView() }

    @objc func preferencePaneCommit() {
        editor.commitAll()
    }
}
