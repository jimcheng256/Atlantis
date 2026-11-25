# Application preferences

`RDAtlantisMainController` registers six panes in startup order and calls
`showPreferences` from its existing Preferences action.
`AtlantisPreferenceController.h` exposes the Swift window controller to
Objective-C through the generated interface. The runtime class and the existing
`init`, `addPane:`, `showPreferences`, and `changeFont:` selectors remain available.

The controller owns the native window and toolbar, the `preferencesWindowFixedSize`
autosave key, and pane selection. `PreferencesPaneHost` wraps the active
pane's view in SwiftUI. The form panes return SwiftUI hosting views. World
Defaults, Hotkeys, and Toolbar Events return the existing AppKit editor views
with their controls and resource connections.
The window opens at the World Defaults content size of 900 × 700 points
unless a frame has been saved under the current autosave key. The new key
starts fresh because the old key stored automatically resized frames.
Switching panes preserves the window frame. Font actions go to the active
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
| General | SwiftUI groups in `GeneralPreferences.swift`. The former `_rdConfigView` is now a hosting view. Former checkbox outlets use option bindings, the beep popup uses a picker, and the URL length field saves on submit or focus loss. Shortcut and badge bindings retain their live callbacks. | Synchronizes user defaults. |
| Network | SwiftUI form in `NetworkPreferences.swift`. Picker selection replaces `_rdProxyType`, toggles replace the performance outlets, and focus tracking replaces the proxy-field key-view chain and editing delegate. | Synchronizes user defaults. |
| World Defaults | The Swift `WorldDefaults` adapter returns `WorldConfigurationEditor.configView`, an AppKit tab view whose child editors own their own resources and outlets under `Preferences/World`. | Calls `commitAll` on the world editor. |
| Hotkeys | `HotkeyPreferences.initForCollection:` takes the shared collection and returns its event editor's `editorView`. The Swift delegate routes key capture and action picking to the shared event editor. | Archives the collection to `hotkeys.akb`. |
| Toolbar Events | `ToolbarEventPreferences.initForEvents:` takes the shared collection and returns its event editor's `editorView`. The Swift delegate routes event creation and picker callbacks to the shared event editor. | Calls `saveToolbarEvents` on the main controller. |
| Windowing | SwiftUI form in `WindowingPreferences.swift`. Pickers replace the grouping and navigator-style outlets. Toggle bindings preserve the native display, icon refresh, and spawn status callbacks. | Synchronizes user defaults. |

The original form XIBs wired outlets and key-view links. Their owners
configured control targets, actions and delegates in `preferencePaneView`.
See the original classes and XIBs in Git history for individual hookups. A pane can
adopt SwiftUI by returning an `NSHostingView` through the same protocol
and retaining its existing commit callback until its callers are migrated.

## Tests

Run the `Atlantis` scheme's hosted `AtlantisTests` target in Xcode.
`AtlantisPreferenceControllerTests` uses spy panes to exercise toolbar
actions and window lifetime without writing real pane preferences. It covers
the Objective-C selectors, lazy pane loading, window dimensions and autosave
name, commit timing, reopening, and font action routing.

The hosting smoke test loads all six pane views, switches through them
using the native toolbar, and checks attachment and size. It substitutes spy
commit callbacks to avoid writing the application's hotkey and toolbar event
archives. A separate hosted text-field test verifies that resizing preserves
the original field editor and text selection.

The pane test classes cover defaults mappings and live callback dispatch,
world editor tab order and commit forwarding, and event collection edits.
The archive tests write to temporary files. Hotkeys verifies decoding with
the app's legacy loader. Toolbar Events verifies the pane's save callback
with the same collection format used by the unchanged application save path.

See the [six-pane workplan](PreferencePaneWorkplan.md) for pass order and regression targets.

## Address Book removal confirmation

The Events, Aliases, and Highlights tabs use the shared Swift
`RemovalConfirmation` sheet. Callers supply the item type and display name.
The Highlights tab uses the pattern as the name and commits the deletion
after the user chooses Remove.
