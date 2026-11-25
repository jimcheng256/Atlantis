# Application preferences

`RDAtlantisMainController` registers six panes in startup order and calls
`showPreferences` from its existing Preferences action.
`AtlantisPreferenceController.h` exposes the Swift window controller to
Objective-C through the generated interface. The runtime class and the existing
`init`, `addPane:`, `showPreferences`, and `changeFont:` selectors remain available.

The controller owns the native window and toolbar, the `preferencesWindow`
autosave key, and pane selection. `PreferencesPaneHost` wraps the active
pane's AppKit view in SwiftUI. It reuses the view created by the legacy pane,
including its controls, outlets, delegates and target/action connections.
The controller sizes the window to the pane and forwards font actions to its
root view or selected tab content. Closing commits every registered pane.
A toolbar selection commits the previous toolbar-selected pane. The first
toolbar selection after window creation skips the initial pane's commit, as
in the original controller. Reopening reuses the same window and pane.

## Pane migration seams

Each pane implements `preferencePaneName`, `preferencePaneImage`,
`preferencePaneView`, and `preferencePaneCommit` in
`Preferences/Application/AtlantisPreferencePane.h`.

| Pane | View and Interface Builder connections | Commit |
| --- | --- | --- |
| General | `GeneralPrefs.xib`, File's Owner `GeneralPreferences`. `_rdConfigView` is the root, with outlets for startup and address book behavior, input handling, beep behavior, shortcuts and Dock badges. | Synchronizes user defaults. |
| Network | `NetworkPreferences.xib`, File's Owner `NetworkPreferences`. `_rdConfigView` is the root, with proxy type, host, port, credentials, compression and disconnection outlets. The proxy fields have a nib key-view chain. | Synchronizes user defaults. |
| World Defaults | `WorldDefaults` returns `WorldConfigurationEditor.configView`, an AppKit tab view whose child editors own their own resources and outlets under `Preferences/World`. | Calls `commitAll` on the world editor. |
| Hotkeys | `HotkeyPreferences.initForCollection:` takes the shared collection and returns its event editor's `editorView`. The pane implements the event editor delegate callbacks. | Archives the collection to `hotkeys.akb`. |
| Toolbar Events | `ToolbarEventPreferences.initForEvents:` takes the shared collection and returns its event editor's `editorView`. The pane implements the event editor delegate callbacks. | Calls `saveToolbarEvents` on the main controller. |
| Windowing | `WindowPrefs.xib`, File's Owner `WindowingPreferences`. `_rdConfigView` is the root, with spawn position/close behavior, window grouping, navigator style and icon-size outlets. | Synchronizes user defaults. |

The three application XIBs wire outlets and key-view links. Their Objective-C
owners configure control targets, actions and delegates in
`preferencePaneView`. The headers and XIB connection sections are the
source of truth for individual hookups when migrating a pane. A pane can
adopt SwiftUI by returning an `NSHostingView` through the same protocol
and retaining its existing commit callback until its callers are migrated.

## Tests

Run the `Atlantis` scheme's hosted `AtlantisTests` target in Xcode.
`AtlantisPreferenceControllerTests` uses spy panes to exercise toolbar
actions and window lifetime without writing real pane preferences. It covers
the Objective-C selectors, lazy pane loading, window dimensions and autosave
name, commit timing, reopening, and font action routing.

The hosting smoke test loads all six real pane views, switches through them
using the native toolbar, and checks attachment and size. It substitutes spy
commit callbacks so that the test leaves real pane settings and archives
alone. A separate hosted text-field test verifies that resizing preserves the
original field editor and text selection.
