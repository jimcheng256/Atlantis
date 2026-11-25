import AppKit

@MainActor
final class RemovalConfirmation: NSObject {
    @objc(presentForWindow:itemType:itemName:onConfirm:)
    static func present(for window: NSWindow, itemType: String, itemName: String?, onConfirm: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if let itemName, !itemName.isEmpty {
            alert.messageText = "Are you sure you want to remove “\(itemName)”?"
        } else {
            alert.messageText = "Are you sure you want to remove this \(itemType)?"
        }

        alert.informativeText = "This \(itemType) will be removed immediately. You can't undo this action."

        let cancel = alert.addButton(withTitle: "Cancel")
        cancel.keyEquivalent = "\u{1B}"
        alert.addButton(withTitle: "Remove").hasDestructiveAction = true

        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn {
                onConfirm()
            }
        }
    }
}
