import AppKit

@MainActor
@objc(ToolbarEventPreferences)
final class ToolbarEventPreferences: NSObject, @preconcurrency AtlantisPreferencePane {
    private let editor = EventEditor()
    private let save: () -> Void

    @objc(initForEvents:)
    convenience init(forEvents collection: ToolbarCollection) {
        self.init(collection: collection, save: { RDPreferenceMainController()?.saveToolbarEvents() })
    }

    init(collection: ToolbarCollection, save: @escaping () -> Void) {
        self.save = save
        super.init()

        editor.setNameColumnTitle("Label")
        editor.setDescriptionColumnTitle("Palette Label")
        editor.addExtraDataColumn("eventIcon", withTitle: "Icon", andCell: NSImageCell(), at: 1)
        editor.setExtraDataColumn("eventIcon", isEditable: false)
        editor.editorView().frame = NSRect(x: 0, y: 0, width: 800, height: 500)
        editor.setDataRepresentation(collection)
        editor.setDelegate(ToolbarEventEditorDelegate(editor: editor, collection: collection))
        editor.setForEventType(ToolbarUserEvent())
    }

    @objc func preferencePaneName() -> String! { "Toolbar Events" }
    @objc func preferencePaneImage() -> NSImage! { NSImage(named: "toolbar") }
    @objc func preferencePaneView() -> NSView! { editor.editorView() }

    @objc func preferencePaneCommit() {
        save()
    }
}

@MainActor
final class ToolbarEventEditorDelegate: PreferenceEventEditorDelegate {
    private let collection: ToolbarCollection

    init(editor: EventEditor, collection: ToolbarCollection) {
        self.collection = collection
        super.init(editor: editor)
    }

    override func conditions() -> [Any] {
        RDPreferenceMainController()?.eventConditions()?.conditions(for: AtlantisTypeUI) ?? []
    }

    @objc func newConditionPicked(_ condition: BaseCondition, context: UnsafeMutableRawPointer?) {
        event(from: context)?.eventAddCondition(condition)
        refreshSelection()
    }

    @objc func addEvent() {
        if let window = editor?.editorView().window {
            window.makeFirstResponder(window)
        }
        let event = ToolbarUserEvent()
        event.eventSetConditionsAnded(true)
        collection.addEvent(event)
        editor?.updateDataRepresentation()
        editor?.selectEvent(event)
    }
}
