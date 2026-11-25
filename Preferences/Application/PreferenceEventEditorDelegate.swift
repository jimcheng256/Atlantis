import AppKit

@MainActor
class PreferenceEventEditorDelegate: NSObject {
    weak var editor: EventEditor?

    init(editor: EventEditor) {
        self.editor = editor
    }

    @objc func actions() -> [Any] {
        RDPreferenceMainController()?.eventActions()?.actions(for: AtlantisTypeUI) ?? []
    }

    @objc func conditions() -> [Any] { [] }

    @objc func newActionPicked(_ action: BaseAction, context: UnsafeMutableRawPointer?) {
        event(from: context)?.eventAddAction(action)
        refreshSelection()
    }

    func event(from context: UnsafeMutableRawPointer?) -> EventDataProtocol? {
        context.flatMap { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() as? EventDataProtocol }
    }

    func refreshSelection() {
        editor?.updateDataRepresentation()
        _ = editor?.perform(NSSelectorFromString("tableViewSelectionDidChange:"), with: nil)
    }

    @objc func addEventAction(_ event: EventDataProtocol) {
        guard let window = editor?.editorView().window else { return }
        ActionPicker.sharedPanel().runSheetModal(
            for: window,
            actions: actions(),
            target: self,
            contect: Unmanaged.passUnretained(event as AnyObject).toOpaque()
        )
    }

    @objc func addEventCondition(_ event: EventDataProtocol) {}
}
