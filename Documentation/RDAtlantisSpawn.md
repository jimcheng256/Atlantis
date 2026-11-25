# Spawn views

Atlantis creates one `RDAtlantisSpawn` for each main or secondary world view. Objective-C callers use `Worlds/RDAtlantisSpawn.h` to access the Swift class through Xcode’s generated header. The class preserves the Objective-C runtime name, initializer, selectors, and Lemuria `RDNestedViewDescriptor` conformance. Its `view()` returns the same hosting view for the life of the spawn. Call the spawn API on the AppKit main thread.

## Implementation

- `RDAtlantisSpawn.swift` registers the descriptor with Lemuria and forwards existing callers to the controller. It handles descriptor identity, child views, focus, and closing.
- `SpawnController.swift` owns the terminal and handles preferences, input submission, output filtering and timestamps, status, and terminal dimensions. It publishes status through `ObservableObject` for macOS 13.5 compatibility. Incoming output still goes directly to AppKit text storage through Lemuria’s buffered append API.
- `SpawnView.swift` lays out the status bar and hosts the terminal through `NSViewRepresentable`. The AppKit status label preserves Cocoa attributes sent by scripts. Changing the bar’s position or visibility preserves the terminal’s SwiftUI identity.
- `SpawnTerminal.swift` creates the two AppKit editors and scroll views once. The controller restores Lemuria’s divider state after the host joins its window, using the same spawn path as before.

## Editor call seams

| Area | Entry points and behavior |
| --- | --- |
| Input editing | The controller sets or inserts text with `stringIntoInput(_:)` and `stringInsertIntoInput(_:)` and reads the draft and selection with `stringFromInput()` and `stringFromInputSelection()`. Insertion replaces the active selection. AppKit selection ranges use UTF-16 offsets. |
| Input submission | `RDAtlantisTextInputView.insertNewline(_:)` sends attributed input through `textView:committedInput:` to the spawn. Shift-Return follows normal newline handling. The input view selects or clears the draft after submission according to `atlantis.text.retainOnCommit`. The controller applies the spawn prefix once and calls `RDAtlantisWorldInstance.handleLocalInput(_:on:)`. |
| Output rendering | The controller filters `RDScreenOmitLine`, handles timestamps and newlines, and sends attributed text to `RDTextView.appendString(_:)`. Preserve its buffering semantics when replacing it. `commit()` flushes pending text. `scrollbackData()` exposes the existing paragraph representation to logging, and `clearScrollback()` calls the editor’s clear operation. |
| Search and selection | The output view handles `searchForString:` and `clearSearchString:` with the existing toolbar sender. The controller obtains the selected output text from the AppKit selection range. Preserve search highlighting, text attributes, copy behavior, and selection across appends and view updates. |
| Sizing and scrolling | `RDScrollView` and its scroller provide sticky autoscroll. The controller observes output viewport and split resize notifications and calculates rows and columns from the visible rect, font metrics, and text-container padding. The main spawn posts `RDAtlantisMainScreenDidChangeNotification` when those dimensions change. |
| Focus and styling | Lemuria calls `viewWasFocused()` and `viewWasUnfocused()` on the spawn. These set the AppKit first responder and show or hide the output tooltip as appropriate. The output requests tooltip permission via `shouldShowTooltipFor:`. The controller applies fonts, colors, paragraph style, link attributes, and scrollback limits. |

Keep editor identity stable during status updates and window moves. A future replacement can implement the corresponding input or output operations at the controller boundary. The spawn facade keeps the same entry points for scripts, events, toolbars, and Lemuria.

## Former Interface Builder wiring

`SpawnView.xib` was removed from the app target. The following table maps its previous owner outlets and cross-editor connections to their current implementations.

| Former outlet or connection | Current implementation |
| --- | --- |
| `contentView`, `splitPlaceholder` | `NSHostingView<SpawnView>` and the programmatically constructed `RBSplitView`. Pane order is output, then input. |
| `inputView`, `outputView` | `SpawnTerminal.inputView` and `outputView`, installed as scroll view document views. |
| `timerField`, `statusField`, `statusBar`, `sslImage` | SwiftUI status bar using `SpawnStatus`, with an AppKit label for attributed status messages. |
| Input `passInputsTo` → output | `RDSpawnSetEditorRouting` wires the legacy outlet ivar in code. The input forwards page scrolling and scroll-to-start/end commands. |
| Output `_rdRedirectFocusOnKeyTo` → input | The same bridge wires the legacy outlet ivar. Typing, pasting, or submitting from the read-only output can redirect focus to input. |
| Input delegate and output tooltip delegate → spawn | The controller assigns both during setup and clears the delegates and keyboard routes when closing. |

The bridge scopes both legacy outlet keys to `RDAtlantisSpawnInterop.m`. Replacing an editor is an opportunity to replace the corresponding KVC connection with an explicit command or callback.

## Tests

Run the hosted XCTest suite with **Product → Test** in the shared Atlantis scheme or use the command below from the repository root. The sibling Lemuria checkout is required.

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

The controller extraction was checked with the XIB in place using the existing tests and a new timestamp and attribute preservation test. The SwiftUI tests cover the host layout and status message, Objective-C selectors, input submission and editor command routing, output filtering and selection, saved divider proportions, and draft, selection, and scrollback preservation across status updates and a window move.
