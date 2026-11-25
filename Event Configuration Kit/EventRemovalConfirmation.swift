import AppKit

@MainActor
final class EventRemovalConfirmation: NSObject {
    @objc(presentForWindow:eventName:onConfirm:)
    static func present(for window: NSWindow, eventName: String?, onConfirm: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if let eventName, !eventName.isEmpty {
            alert.messageText = "Are you sure you want to remove “\(eventName)”?"
        } else {
            alert.messageText = "Are you sure you want to remove this event?"
        }
        
        alert.informativeText = "This event will be removed immediately. You can't undo this action."

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
