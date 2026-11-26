import AppKit

@MainActor
@objc(HotkeyPreferences)
final class HotkeyPreferences: NSObject, @preconcurrency AtlantisPreferencePane {
    private let collection: HotkeyCollection
    private let editor = EventEditor()
    private let archiveURL: URL

    @objc(initForCollection:)
    convenience init(for collection: HotkeyCollection) {
        self.init(
            collection: collection,
            archiveURL: URL(fileURLWithPath: RDAtlantisStoragePath("hotkeys.akb"))
        )
    }

    init(collection: HotkeyCollection, archiveURL: URL) {
        self.collection = collection
        self.archiveURL = archiveURL
        super.init()

        let cell = NSButtonCell()
        cell.setButtonType(.switch)
        cell.imagePosition = .imageOnly
        cell.type = .imageCellType
        editor.setNameColumnTitle("Key")
        editor.addExtraDataColumn("eventGlobal", withTitle: "Global", andCell: cell, at: 1)
        editor.setDataRepresentation(collection)
        editor.setDelegate(HotkeyEditorDelegate(editor: editor, collection: collection))
        editor.setForEventType(HotkeyEvent())
        editor.editorView().frame = NSRect(x: 0, y: 0, width: 800, height: 500)
    }

    @objc func preferencePaneName() -> String! { "Hotkeys" }
    @objc func preferencePaneImage() -> NSImage! { NSImage(named: "PTKeyboardIcon") }
    @objc func preferencePaneView() -> NSView! { editor.editorView() }

    @objc func preferencePaneCommit() {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: collection, requiringSecureCoding: false)
        try? data?.write(to: archiveURL, options: .atomic)
    }
}

@MainActor
final class HotkeyEditorDelegate: PreferenceEventEditorDelegate {
    private let collection: HotkeyCollection

    init(editor: EventEditor, collection: HotkeyCollection) {
        self.collection = collection
        super.init(editor: editor)
    }

    @objc func keyComboPanelEnded(_ panel: PTKeyComboPanel) {
        guard let key = panel.keyCombo() else { return }
        addKey(key)
    }

    func addKey(_ key: PTKeyCombo) {
        guard key.isValidHotKeyCombo() else { return }
        let event = HotkeyEvent()
        event.setKeyCombo(key)
        event.eventSetEnabled(true)
        collection.addEvent(event)
        editor?.updateDataRepresentation()
        editor?.selectEvent(event)
    }

    @objc func addEvent() {
        guard let window = editor?.editorView().window,
              let panel = PTKeyComboPanel.sharedPanel() as? PTKeyComboPanel,
              let hotkey = PTHotKey() else { return }
        hotkey.setKeyCombo(PTKeyCombo())
        hotkey.setName("set hotkey")
        panel.showSheet(forHotkey: hotkey, for: window, modalDelegate: self)
    }
}
