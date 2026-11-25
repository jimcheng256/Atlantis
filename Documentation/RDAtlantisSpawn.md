# Spawn views

Atlantis creates one `RDAtlantisSpawn` for each main or secondary world view. The Swift implementation in `Worlds/Spawn/RDAtlantisSpawn.swift` owns the AppKit view hierarchy, input routing, scrollback, nested view metadata, and status bar. It runs on the main actor. Objective-C callers keep importing `Worlds/RDAtlantisSpawn.h`, which exposes the Swift class through Xcode’s generated header. The class keeps its Objective-C runtime name, initializer selector, and Lemuria `RDNestedViewDescriptor` conformance.

`RDAtlantisSpawnInterop` calls APIs whose legacy signatures Swift cannot import directly. The bridge also reuses Lemuria’s view comparator, legacy divider image setup, and the existing scrollback paragraph representation.

## Editing the view

Open `Worlds/Spawn/SpawnView.xib` in Interface Builder. Xcode compiles it to `SpawnView.nib` in the app bundle. The XIB supplies the content view, output and input scroll views, and status bar. Its two pane children are ordered output first and input second. At load time the Swift owner moves them into a Lemuria `RBSplitView`, using their XIB dimensions as the initial geometry. The split view restores saved proportions using the spawn’s existing view path. Swift also applies the top or bottom status bar preference and resizes the split area when the bar is hidden.

Keep the existing text view classes and both keyboard connections when editing the view. The input’s `passInputsTo` points to the output for scrolling commands. The output’s `_rdRedirectFocusOnKeyTo` points to the input so typing or pasting from the output can move focus. The Swift owner installs itself as input delegate to receive `textView:committedInput:`.

## Tests

Run the hosted XCTest suite with **Product → Test** in the shared Atlantis scheme or use the command below from the repository root. The sibling Lemuria checkout is required, as for an app build.

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

The tests in `Tests/AtlantisTests/RDAtlantisSpawnTests.swift` instantiate the production Swift class and compiled nib with a local test world. They check the Objective-C selectors, custom view classes, keyboard outlets, status bar placement and visibility, terminal size, saved divider proportions, input selection and insertion, committed input prefixes, and output filtering, selection, newline handling, and clearing.
