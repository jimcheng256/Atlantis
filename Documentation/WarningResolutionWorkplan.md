# Atlantis warning resolution workplan

Status as of 2026-11-26 is **planned, awaiting review**. The starting point
is `warning-resolution` at `ee9deed`. The fresh Debug build succeeded with
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
- For every substantive change, write focused unit tests and run them
  against the original implementation before changing it. Run the same
  assertions against the revised implementation. Compare observable
  results, including bytes on the wire, decoded text and attributed runs,
  persisted values, errors, callbacks, or responder behavior as applicable.
  Use hosted tests when behavior depends on the actual window, pane, or
  editor. Use temporary defaults suites and archive paths for persistence
  tests.
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
| `Event System/AtlantisState.m:82`, `Event System/Conditions/Condition-ComputerIdle.m:37`, `Worlds/RDAtlantisWorldInstance.m:753` | Verify intended units and precision for the `NSTimeInterval` arguments, including fractional values. |
| `MCP System/MCPMessage.m:224` | Verify the integer type and the field's role. Compare exact encoded bytes if it goes on the wire. |
| `Preferences/World/WorldSpawnEditor.m:960`, `Worlds/AddressBook.m:788` | Verify the displayed messages preserve literal percent signs and interpolated text. |

## Between-increment gate

1. Before the first increment, establish the smoke baseline with a dedicated
   test world and disposable data. Record the app version, Xcode version,
   architectures, fixture configuration, and any existing failures.
2. For each increment, run the smallest focused checks before the edit and
   again afterward. Run the shared hosted suite for changes involving
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
4. Run the entire smoke checklist below, with extra coverage for the
   affected subsystem. Record pass, fail, or blocked for each row and
   include the fixture and observed result for any deviation. Stop for
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

## Application smoke checklist

Use a disposable Address Book entry, a local Telnet fixture, and temporary
log files. Preserve real profiles and network credentials. Keep the
fixture and checks the same between increments.

Create a small smoke runner before the first source edit and use it for
the initial baseline and subsequent increments. Have it accept the built
app path and an output directory outside the checkout. Record the commit,
app version, build toolchain and SDK, and binary architectures. Start a
loopback Telnet fixture and record negotiation, expected command bytes,
actual received bytes, and a transcript. Pin the fixture inputs, including
the ANSI and Truecolor output chunks and the split prompt.

Use a disposable macOS test account or a verified isolated app data
environment. Record and verify where Atlantis resolves preferences and
archives before running the GUI checks, and store logs in temporary paths.
Have the runner print the connection details and prepare a result sheet
for the operator to mark each row pass, fail, or blocked, with observations
and artifact paths. Keep visual layout, focus, menus, and window restoration
in the operator checklist.

| Area | Check and expected result |
| --- | --- |
| Launch, menus, and main window | Launch the fresh app, open About and the principal menus, and open and close the Address Book and Preferences. Confirm menus work, windows activate, and focus returns to the expected view. |
| Address Book and world editor | Open a disposable world and character. Visit the connection and formatting tabs, edit and save a test preference, then reopen and verify it. Cancel a second edit and confirm the saved value persists. |
| Main Preferences | Visit General, Network, World Defaults, Hotkeys, Toolbar Events, and Windowing. Resize the window, switch panes, and confirm labels, scrolling, focus, and saved settings remain usable. |
| Connection, input, and output | Connect to the local fixture, send an ASCII command and a multibyte command, and compare the received bytes. Verify normal output, ANSI palette and Truecolor text, a split prompt, input echo, scrollback, and clean disconnect and reconnect. |
| Spawns, tabs, and windowing | Open or route output to a secondary spawn. Switch tabs and worlds, exercise an input split and status bar, resize, and verify input focus, scrolling, and output routing. |
| Events, aliases, hotkeys, and scripts | Exercise a disposable alias, a line event that routes or highlights output, a configured hotkey or toolbar action, and a small local JavaScript callback. Check each fires once and the resulting text reaches the expected pane. |
| Logging and editors | Open and close plain and HTML logs and inspect text and color output. Open the MUSH editor, exercise keyboard focus and a basic edit, and verify cancel or close returns to the session. |
| Quit and relaunch | Quit cleanly, relaunch, and confirm the disposable world, saved settings, and expected window state persist. Check the process log for unexpected errors. |

No warning fixes, characterization tests, or smoke runs have been started
under this workplan.
