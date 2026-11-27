# Atlantis warning resolution workplan

Status as of 2026-11-26 is **under review after the Spawn removal sheet batch in increment 3**.
The starting point is `warning-resolution` at `ee9deed`. The fresh Debug build succeeded with
2,182 captured warning lines, including repeats, dependency diagnostics, and
Xcode output. Atlantis source and resource paths accounted for 1,421 lines.
The remaining 63 lines comprise 52 Xcode environment lines, 6 diagnostic
echoes, and 5 pathless build or project diagnostics, including one for Lemuria.

The scope is Atlantis code, resources, and project settings. Lemuria stays
in the build for integration coverage. Leave its 698 path-attributed warning
lines and its own project settings outside this workplan. Track Xcode
environment diagnostics separately from the Atlantis warning counts.

## Review and verification rules

- Work on one warning set at a time. Before editing, record the exact
  warning sites, their owning target, and the proposed scope. Keep changes
  for independent subsystems separately reviewable, especially within the
  larger sets. Preserve unrelated working-tree changes.
- Treat Xcode fix-its and “equivalent” suggestions as hypotheses. A
  name-only change or a documented deprecated constant replacement can use
  existing coverage after verifying the mapping. Any substantive change
  requires reviewing the old and new API contracts, callers, and runtime
  behavior. Check Objective-C selectors, AppKit ownership and lifecycle,
  Swift imports, and existing archive or wire formats where relevant.
- For every substantive change, express the focused behavior probes as
  standalone unit tests under `Tests/WarningResolution` and keep them in version
  control with the increment. Keep hosted coverage in `Tests/AtlantisTests`.
  Exercise the production code or expressions using deterministic fixtures.
  Run the same assertions against the original implementation before editing
  it and against the revised implementation afterward. Assert observable
  results, such as exact wire bytes, decoded text, persisted values, or
  errors. Add hosted tests where verification requires the actual window,
  pane, or editor. Use temporary defaults suites and archive paths for
  persistence tests.
- Record the source revisions, test paths and commands, expected results,
  and observed outcomes for each increment in the handoff. Identify
  intentional behavior corrections and any baseline checks that fail to
  compile or run. Keep the tests and this evidence available so a later
  regression can be traced by rerunning the relevant checks at earlier
  revisions.
- For numeric and byte-length changes, identify the unit and signedness at
  each boundary. Exercise zero, normal values, boundary values on both
  sides of a conversion, sentinels such as `NSNotFound`, split input,
  truncated input, and multibyte text where applicable. Assert exact bytes,
  range endpoints, and buffer consumption. Use synthetic values to test
  limits without large allocations. For unavoidable narrowing into a C or
  protocol field, test the intended overflow handling.
- If a warning exposes a bug, characterize the existing behavior and
  record the proposed behavior change for review. Preserve the valid-input
  cases and add a separate regression assertion for the agreed correction.
  A newly passing test on the revised implementation alone is insufficient
  evidence for an equivalence claim.

## Prerequisite: optional profile directory

Before the application smoke baseline and the first warning increment,
implement and verify an optional Atlantis profile directory. Keep the
implementation in a separate commit for review.

- Accept `--profile-directory <path>` at startup, before loading preferences,
  archives, or windows. Preserve existing storage behavior when the flag
  is absent. Reject an unusable path before loading profile data.
- Use a dedicated `NSUserDefaults` suite for each profile and resolve
  Atlantis-managed files under the selected directory. Audit direct
  defaults access, Cocoa bindings, SwiftUI storage, and home-relative
  paths for worlds, hotkeys, toolbar events, globals, and default logs.
  The smoke checks cover Atlantis-owned settings. macOS-managed
  settings and AppKit window restoration are outside the checklist.
- Use two temporary profiles for verification. Save a preference and a
  world in the first, relaunch to confirm persistence, and confirm the
  second profile starts without either value. Verify that the isolated
  run leaves the normal Atlantis-owned preferences and archive paths
  untouched.
- Record the effective preference suite and storage paths in the smoke
  capture. Retain the warning capture from `ee9deed` and take a fresh
  capture from the accepted profile-support commit. Compare the two for
  diagnostics introduced by the prerequisite. Use the accepted commit
  for the application smoke baseline and the first increment comparison.

## Increment order

Counts are Atlantis-path warning lines from the baseline, including
repeats. Count distinct warning sites separately during each increment.

| Increment | Baseline lines | Mitigation risk and verification |
| --- | ---: | --- |
| 1. Format strings and faulty expressions | 20 | Low to medium effort with potentially important correctness changes. Check format specifiers and literal formatting, including percent signs in input. Isolate real behavior changes such as the HID idle-time length guard and test valid and malformed inputs. |
| 2. Deprecated constants and mechanical cleanup | 384 constants plus eligible items from 106 cleanup lines | Low for confirmed constant aliases, redundant literals, and genuinely unused locals. Verify values and imported types. Move changes with side effects or uncertain equivalence into a later tested batch. |
| 3. Integer narrowing | 318 | Start with local AppKit indexes and counts. Review networking, compression, and other byte or C API boundaries separately. Use the numeric verification rules above and require byte-for-byte results for valid input. |
| 4. API contracts and nullability | 92 contract lines plus remaining cleanup annotations | Verify declarations against implementations and callers. Cover nil behavior, return values, selector dispatch, callbacks, and Swift actor or bridging contracts. Run the hosted tests for affected editors and preferences. |
| 5. Deprecated API replacements | 368 | Split by subsystem, such as nib and sheet lifecycle, drawing and presentation, and archive or file handling. Treat persistence migrations separately. Test old archives, current round trips, and error paths, and compare visible output where applicable. |
| 6. XIB layout and compatibility | 132 | Work by window or pane. Compare initial layout, resizing, minimum size, clipping, labels, key-view order, and focus on the affected resources in the hosted app. |
| 7. Atlantis project and build settings | 1 path-attributed line plus Atlantis target diagnostics | Review bundle identifier, header search, script phase, and metadata diagnostics separately. Lint project-file changes, build with fresh Derived Data, and inspect the app bundle, embedded frameworks, resources, and version metadata. |

## First-increment inventory

The 20 captured lines represent nine source sites. The HID guard emits two
diagnostic kinds, and the Open Log diagnostic describes `BOOL` differently
on arm64 and x86_64.

| Source site | Focused verification |
| --- | --- |
| `Utility Classes/HIDIdleTime.m:45` | Verify valid data and number paths. Specify expected results for short and oversized payloads as a separate correction to the ineffective guard. |
| `Utility Classes/RDStringPattern.m:192` | Exercise the invalid-regex path with percent signs and inspect the logged message. |
| `Event System/Actions/Action-OpenLog.m:313` | Check the Options button for log types with and without options on editor load and after switching types. |
| `Event System/AtlantisState.m:82`, `Event System/Conditions/Condition-ComputerIdle.m:37`, `Worlds/RDAtlantisWorldInstance.m:754` | Verify intended units and precision for the `NSTimeInterval` arguments, including fractional values. |
| `MCP System/MCPMessage.m:224` | Verify the integer type and the field's role. Compare exact encoded bytes if it goes on the wire. |
| `Preferences/World/WorldSpawnEditor.m:960`, `Worlds/AddressBook.m:789` | Verify the displayed messages preserve literal percent signs and interpolated text. |

### First-increment behavior

- HID idle-time decoding still accepts numeric values and exact eight-byte
  payloads. It now returns zero for short or oversized payloads and uses a
  bounded copy. This also removes the warning for the deprecated copy method.
- Invalid regex diagnostics and both confirmation messages preserve percent
  signs in interpolated text. The Open Log editor reads the log format's
  boolean capability directly. The hosted test exercises its Options button
  on initial load, after switching formats, and when refreshing the editor.
- `world.connected` reports completed seconds and retains the offline
  sentinel `-1`. The Computer Idle description retains fractional seconds
  from its configured threshold.
- The MCP session key uses whole seconds since the Foundation reference
  date and is cached as before. Multiline data tags retain their prefix and
  minimum four-digit lowercase hex format. The formatter now uses the
  full-width counter, so the tag continues growing beyond 32 bits.

See the [handoff](WarningResolutionHandoff.md#first-increment-results) for
the verification record.

Run the seven standalone format tests with full Xcode selected. They
compile the production format expressions and MCP encoder into a
temporary process. The alert cases use AppKit in the current user session.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_warning_formats.py -v
```

## Second-increment scope

- Replace numeric AppKit aliases for control state and size, modal
  responses, mouse and keyboard events, and modifier masks.
- Simplify redundant immutable string literals and remove the unused
  `slashIndex` local in `UKCreateDictionaryFromXML`.
- Review nullability and symbol visibility annotations with the API
  contracts increment.

### Deferred pasteboard migration

- During deprecated API replacements, add a standalone test in
  `Tests/WarningResolution` using a uniquely named pasteboard in the current user
  session. Write with each of `NSStringPboardType` and
  `NSPasteboardTypeString` and read with both. Assert exact text, including
  Unicode and line breaks. For the MUSH editor, also assert that the
  custom `RDTextType` bytes survive alongside the plain-text representation.
- Use those results to migrate the input-copy action, output-copy action,
  and MUSH editor together. Preserve legacy compatibility for any reader
  that loses access. Rerun the standalone checks and the application smoke
  suite, and record the results in the handoff.

### Deferred MCP editor cleanup

- Use a synthetic MCP edit message in a hosted test in the current user
  session. Check the editor title and contents, exercise Send and Close,
  and trace controller ownership through window close. Capture the Send
  response in a test fixture.
- If the existing lifetime is sound, discard the unused initializer
  result explicitly while preserving the call and ownership. If the
  ownership needs correction, give it a separately reviewed change with
  lifecycle coverage. Rerun the hosted checks and application smoke suite,
  and record the results in the handoff.

## Third-increment batches

The first batch covers the Action and Condition picker sheet callbacks.
Read the signed AppKit selection index directly and check it against the
backing array count before dispatching. Verify ordinary selections, wide
indexes, missing selections, and out-of-range indexes independently of
the hosted application.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_picker_indexes.py -v
```

The second batch covers the World Configuration tab commit and Open Log
format selection and restoration. Preserve full-width selections and
verify that a missing or out-of-range selection leaves the current
configuration alone. Use synthetic indexes above the 32-bit range.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_editor_indexes.py -v
```

The third batch covers the log-closing table. Match AppKit's data-source
signatures and verify row counts, zero-based labels, metadata lookups,
and closing the selected log with ordinary and synthetic wide indexes.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_log_closer_indexes.py -v
```

The fourth batch covers the User Variables table in World Configuration.
Match AppKit's signed row count and row parameters, and keep the index used
to select and edit a newly added variable at full width. Verify empty,
ordinary, and synthetic wide tables, and use the hosted editor to check
selection before and after adding a variable.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_user_variable_indexes.py -v
```

The fifth batch covers the Highlights table in World Configuration.
Use AppKit row types for data-source callbacks and edits to the selected
row. Check the array's missing-index sentinel before selecting an added
highlight. Validate the pattern popup selection before converting it
to the stored pattern type. The hosted editor verifies selection after
Add and the removal confirmation flow.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_highlight_indexes.py -v
```

The sixth batch covers click hit testing in the shared outline view used
by the Address Book and Spawn editor. Keep AppKit row and column indexes
at full width. Forward clicks outside a row or column to AppKit without
calling the delegate. Verify ordinary, wide, and missing indexes with
the standalone probe and check delegate dispatch in the hosted Spawn
editor.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_outline_click_indexes.py -v
```

The seventh batch covers the Spawn editor outline data source, selection
refresh and restoration, and selection and editing of an added spawn.
Verify child counts and indexes, wide rows, and missing selections.
Use the hosted editor to check that an added child stays selected when
renaming it reloads the outline. The removal sheet's row context and
the pattern and exception tables have their own warning sites.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_spawn_outline_indexes.py -v
```

The eighth batch covers the Spawn editor's pattern and exception tables.
Match AppKit's row count and row parameters. Verify reads and edits at
ordinary and wide indexes, check the missing index when adding a row,
and validate the selection before copying the list for removal. Use
the hosted editor to verify adding, editing, and removing a row in
both tables.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_spawn_pattern_indexes.py -v
```

The ninth batch covers the row passed to the Spawn removal sheet.
Preserve the signed AppKit index across the callback and retain its
context until the callback releases it. Verify ordinary and wide rows,
canceling, missing selection, and a detached editor. Use the hosted
editor to check both buttons on the actual sheet.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_spawn_removal_indexes.py -v
```

Review each batch before taking on more AppKit indexes and counts. Keep
networking, compression, and other byte-level conversions in separate
batches.

## Between-increment gate

1. After profile support is accepted and before the first increment,
   establish the smoke baseline with a dedicated test world and disposable
   data. Record the app version, Xcode version, architectures, fixture
   configuration, and any existing failures.
2. For each increment, run the focused standalone unit tests before the edit
   and again afterward, then record the evidence in the handoff. Run the
   shared hosted suite for changes involving
   windows, panes, or editors. If Xcode requires separate environments, use
   `build-for-testing` and `test-without-building` with the same settings and
   Derived Data path. Report compilation and hosted execution separately.
3. Build the shared Atlantis scheme with fresh Derived Data for the warning
   comparison. Use the baseline configuration and architecture settings.
   Save the full log and a numbered warning extract outside the repository.
   Compare Atlantis sites by owning target, file and source position, and
   diagnostic kind. Account for shifted source lines when matching sites
   across edits. Retain raw counts and architecture repeats. Attribute
   pathless diagnostics by target or enclosing build step where possible.
   Report Lemuria, diagnostic echoes, and Xcode environment lines separately.
4. Run the automated application smoke suite below, with extra coverage
   for the affected subsystem. Keep the XCTest result bundle, capture
   summary, and test log with the warning comparison. Stop for
   review if the change introduces a regression or a behavior change
   outside the agreed scope. Review each increment before starting the next.

The captured Debug build used the macOS 26.5 SDK and compiled for arm64
and x86_64. Record the Xcode build version, SDK, and actual build
architectures on each run. On this machine, full Xcode is installed at
`/Applications/Xcode.app` (26.6, build 17F113). Use its developer directory
explicitly when Command Line Tools is selected. Use fresh Derived Data
for each warning comparison.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
capture_dir="$(mktemp -d /tmp/atlantis-warning-resolution.XXXXXX)"
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$capture_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO build > "$capture_dir/build.log" 2>&1
```

Use the same full Xcode selection for the shared Debug hosted suite.

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

## Automated application smoke tests

Run from the current macOS user context. The runner stages the Debug
products from `build-for-testing` and starts the hosted XCTest app with
a temporary bundle identifier and a new Atlantis profile. The original
build products stay intact. The test app uses its own macOS application
domain, a profile-specific Atlantis preferences suite, and a disposable
archive directory.
The runner records the effective profile and suite, toolchain, build
architecture, test log, and XCTest result bundle.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
smoke_dir="$(mktemp -d /tmp/atlantis-smoke.XXXXXX)"
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$smoke_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO build-for-testing > "$smoke_dir/build.log" 2>&1
python3 Tests/Smoke/run.py "$smoke_dir"/DerivedData/Build/Products/*.xctestrun \
  "$smoke_dir/results" --build-log "$smoke_dir/build.log" --revision "$(git rev-parse HEAD)"
```

| Application area | Automated coverage |
| --- | --- |
| Launch and profile | Start the hosted app with a disposable profile. Verify that Atlantis resolves storage to that profile and that preferences and worlds persist when reopened in a separate store instance. |
| Preferences and world editors | Open the hosted preference panes, switch panes, commit changes, and exercise live focus and resize behavior. Verify network settings, world defaults, hotkey archives, and toolbar event archives. |
| Connection, input, and output | Connect a real Atlantis world to the loopback fixture. Verify ASCII and UTF-8 command bytes, a palette banner, a Truecolor prompt with a split sequence, disconnect, and reconnect. |
| Spawns and events | Exercise hosted terminal input, scrollback, draft selection, spawn routing, in-app splits, event confirmation, and JavaScript callbacks and timers. |
| Logging | Verify plain, formatted, and HTML output, including Truecolor rendering in WebKit. |

The smoke suite excludes macOS settings, live notification delivery,
Dock integration, and saved window frames. Add targeted hosted checks
when an increment affects an application path this suite does not exercise.

The post-profile warning baseline is captured at `9910494`.
