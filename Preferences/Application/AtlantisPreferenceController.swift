import AppKit
import SwiftUI

@MainActor
@objc(AtlantisPreferenceController)
final class AtlantisPreferenceController: NSWindowController, NSToolbarDelegate, NSWindowDelegate {
    // Previous versions autosaved the size of whichever pane was selected.
    static let frameAutosaveName = "preferencesWindowFixedSize"

    private var panes: [String: AtlantisPreferencePane] = [:]
    private var order: [String] = []
    private var toolbarItems: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private var activePaneView: NSView?
    private var lastPane: AtlantisPreferencePane?

    @objc override init(window: NSWindow?) {
        super.init(window: window)
    }

    @objc convenience init() {
        self.init(window: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc(addPane:)
    func add(_ pane: AtlantisPreferencePane) {
        let name: String = pane.preferencePaneName()
        panes[name] = pane
        order.append(name)
    }

    @objc func showPreferences() {
        if let window {
            window.makeKeyAndOrderFront(self)
            return
        }
        guard let first = order.first else { return }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: WorldDefaults.defaultContentSize),
            styleMask: [.closable, .resizable, .titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Atlantis Preferences"
        window.showsResizeIndicator = false

        for name in order {
            let identifier = NSToolbarItem.Identifier(name)
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.paletteLabel = name
            item.label = name
            item.image = panes[name]?.preferencePaneImage()
            item.target = self
            item.action = #selector(toolbarItemClicked(_:))
            toolbarItems[identifier] = item
        }

        let toolbar = NSToolbar(identifier: "AtlantisPrefsToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        window.toolbar = toolbar
        window.delegate = self
        self.window = window
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            // Attaching the toolbar can change AppKit's content size.
            window.setContentSize(WorldDefaults.defaultContentSize)
            window.center()
        }
        if !RDAtlantisHasProfile() {
            window.setFrameAutosaveName(Self.frameAutosaveName)
        }

        selectPane(first, in: window)
        // The initial pane becomes eligible for a switch commit after a toolbar selection.
        lastPane = nil
        window.makeKeyAndOrderFront(self)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        order.map { NSToolbarItem.Identifier($0) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        toolbarItems[itemIdentifier]
    }

    @objc func validateToolbarItem(_ item: NSToolbarItem) -> Bool { true }

    @objc private func toolbarItemClicked(_ item: NSToolbarItem) {
        guard let window else { return }
        selectPane(item.itemIdentifier.rawValue, in: window)
    }

    private func selectPane(_ name: String, in window: NSWindow) {
        lastPane?.preferencePaneCommit()
        guard let pane = panes[name], let view = pane.preferencePaneView() else { return }

        let host = NSHostingView(
            rootView: PreferencesPaneHost(paneView: view)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        host.sizingOptions = []
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.recalculateKeyViewLoop()
        activePaneView = view
        window.title = name
        lastPane = pane
    }

    func windowWillClose(_ notification: Notification) {
        for pane in panes.values {
            pane.preferencePaneCommit()
        }
    }

    @objc func changeFont(_ sender: Any?) {
        var view = activePaneView
        if let tabs = view as? NSTabView {
            view = tabs.selectedTabViewItem?.view
        }
        let action = #selector(changeFont(_:))
        if let view, view.responds(to: action) {
            _ = view.perform(action, with: sender)
        }
    }
}
