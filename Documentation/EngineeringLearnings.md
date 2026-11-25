# Engineering learnings

Record verified findings here when they are likely to save time in a future
session. Include the affected code path, what was observed, and how it was
verified. Update entries when the implementation changes. Use feature docs
for detailed design and test instructions.

## Objective-C and Swift interoperability

- Check the actual Objective-C selector behind a Swift initializer or
  factory call. During the preferences migration, the importer suggested
  `RDAtlantisMainController()` for `+controller`, but the compiled call
  allocated an instance and sent `-init`. Likewise, plain
  `WorldConfigurationEditor()` did not call `-initWithGlobalWorld`.
  The typed bridges in `Atlantis-Bridging-Header.h` preserve both calls.
  Hosted tests verify the application singleton identity and the real
  global editor's tabs.
- Legacy `EventEditor` retains its delegate. The Swift preferences
  delegates hold the editor weakly so the editor can release them at
  teardown. Event picker callbacks still receive a legacy context pointer
  to the intended event.
- An AppKit view hosted in SwiftUI can carry field-editing state, selection,
  scrollback, and responder relationships. Retain the native view instance
  across SwiftUI updates when those behaviors matter. The spawn tests
  exercise this across status changes and window moves.

## Preferences layout and window sizing

- For vertically scrollable forms, give the section stack its natural
  height. The General pane uses a vertically fixed-size stack inside its
  scroll view. Its hosted test measures section frames relative to the
  scroll viewport. Window-relative coordinates include offsets such as
  the title bar and can give misleading clipping assertions.
- Attaching the native toolbar can change the AppKit content size. Apply
  the default size after installing the toolbar. Preferences uses the
  World Defaults content size and a fresh frame autosave key because the
  former key could contain an automatically resized pane frame. Hosted
  tests cover first open, resizing, pane switching, and frame restoration.

## Building, testing, and publishing

- The version-generation build phase can modify
  `English.lproj/InfoPlist.strings` with a new build date or copyright year.
  Check the diff before staging and keep the generated change out of
  unrelated commits.
- A hosted build can succeed while XCTest execution is blocked from reaching
  macOS GUI or test-manager services. In the migration session,
  `build-for-testing` ran separately from `test-without-building`, which
  needed access to the host session. A universal build verifies that both
  architectures compile. The preferences migration tests ran on Intel.
- Git SSH push access and GitHub PR creation permissions are independent.
  The GitHub integration returned HTTP 403 for PR creation on the fork
  even though the branch push succeeded. If that recurs, verify the
  integration's access to the intended fork. A comparison URL in the fork
  can preselect `main` and the feature branch for a signed-in maintainer.
