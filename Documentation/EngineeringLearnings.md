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

- A narrowing warning inside an AppKit callback can expose a protocol
  signature mismatch. In `RDLogCloser`, an Intel probe calling the legacy
  row-count method through `NSTableViewDataSource` observed the expected
  wide count despite its `int` return declaration. Runtime type encodings
  exposed the mismatch, and a wide row separately showed truncation in the
  label and metadata lookup. Check the Objective-C signature alongside
  the returned values when testing these callbacks.

- A fresh Atlantis build can report the same diagnostic for arm64 and
  x86_64 and include warnings from the Lemuria project reference. The
  warning-resolution baseline contained 2,182 captured lines, of which
  1,421 had Atlantis paths and 698 had Lemuria paths. Keep the raw log with
  repeats, then group diagnostics by owner and source site for comparison.
  Count pathless build settings by target and record Xcode environment
  diagnostics separately.
- Warning count alone can hide a behavior bug. The initial audit found an
  ineffective length guard in `HIDIdleTime.m` and an `NSLog` call in
  `RDStringPattern.m` that treats a constructed message as its format.
  Review those as correctness changes with explicit expected results. For
  equivalence claims on API or numeric changes, run the same characterization
  assertions on both implementations and include malformed input and byte
  boundaries where relevant.
- A runtime nib lookup can resolve to a resource compiled from a same-named
  XIB. After removing the unreferenced legacy nib packages, a clean build
  contained all 47 replacement nibs compiled from the XIBs in the Resources
  build phase.
- Xcode group membership, target membership, and on-disk location are
  independent. `LogsCommand` and `RDMultibyteFilter` were already in their
  respective Xcode groups. Moving the files into those directories required
  updating their file-reference paths while keeping the existing Sources
  entries. The Debug build compiled both implementations from their new
  paths on arm64 and x86_64.
- The version-generation build phase can modify
  `English.lproj/InfoPlist.strings` with a new build date or copyright year.
  Check the diff before staging and keep the generated change out of
  unrelated commits.
- A hosted build can succeed while XCTest execution is blocked from reaching
  macOS GUI or test-manager services. In the migration session,
  `build-for-testing` ran separately from `test-without-building`, which
  needed access to the host session. A universal build verifies that both
  architectures compile. The preferences migration tests ran on Intel.
- Hosted smoke tests run in the current user context. The smoke runner
  copies the Debug products and gives the copy a disposable bundle identifier
  and an Atlantis profile directory. The bundle identifier separates AppKit
  and Lemuria's standard defaults. The profile separates Atlantis preferences
  and archives. Verify the runtime profile and retain the XCTest result
  bundle. The smoke suite covers in-session layout and focus and excludes
  macOS integrations and saved window positions.
- A loopback test using a real Atlantis world waits for the listener to
  publish a nonzero port. For a prompt without a trailing newline, send
  Telnet Go Ahead after the final chunk so Atlantis releases the buffered
  prompt. Use the hosted spawn to verify visible text and color, then assert
  exact command bytes and CRLF at the server on both connections.
- Git SSH push access and GitHub PR creation permissions are independent.
  The GitHub integration returned HTTP 403 for PR creation on the fork
  even though the branch push succeeded. If that recurs, verify the
  integration's access to the intended fork. A comparison URL in the fork
  can preselect `main` and the feature branch for a signed-in maintainer.
