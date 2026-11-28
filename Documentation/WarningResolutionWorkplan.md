# Atlantis warning resolution workplan

Status as of 2026-11-27 is **increment 3 through batch 42**,
the Dock badge count. See the
[handoff](WarningResolutionHandoff.md#resume-here) for the resume point.

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

The tenth batch covers the Address Book outline data source. Match
AppKit's child count and child index types for worlds and characters.
Verify ordinary, wide, missing, and out-of-range indexes, and exercise
expansion and collapse in the hosted Address Book with a disposable
world collection.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_address_book_outline_indexes.py -v
```

The eleventh batch covers Address Book selection, reload, and editor tab
restoration. Keep row and tab indexes at AppKit width and restore a tab
only when the destination contains that index. Verify missing and wide
selections independently and switch between a world and character in
the hosted editor.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_address_book_selection_indexes.py -v
```

The twelfth batch covers the Address Book rows selected by Add World,
Add Character, and Focus World. Verify ordinary and wide row indexes
and preserve the current selection when AppKit cannot resolve a row.
Exercise the three actions with a disposable hosted world collection.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_address_book_action_indexes.py -v
```

The thirteenth batch covers the Address Book connection column and
lookup of an existing configuration tab. Keep both indexes at full
width and honor the missing lookup sentinel. Verify in the hosted
Address Book that the connection column is first and that adding a
character creates one editor tab even when the editor is installed twice.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_address_book_lookup_indexes.py -v
```

The fourteenth batch covers the Event Editor table data-source callbacks.
Match AppKit's row signatures and validate the row before converting it
for EventCollection. Exercise ordinary edits and invalid rows in the
hosted editor.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_table_indexes.py -v
```

The fifteenth batch covers Event Editor `moveUp:` and
`moveDown:`. At `c3ae6e1`, the six sites in `Event Configuration Kit/EventEditor.m`
are at lines 257, 266, 275, 286, 295, and 304. Characterize both condition
and action moves before editing. Cover ordinary and wide indexes,
missing or out-of-range selected rows, missing chain items, and the
first and last positions. Verify that a successful move sends the same
destination to the event model and its chain view.

A synthetic probe against the original `BaseEvent` move implementations
showed that moving from `INT_MAX + 1` to `INT_MAX` passes an out-of-bounds
source to the array exchange. Both the event model and Lemuria's
`RDChainedListView` store the source index in an `int`. The Event Editor
now validates its selected AppKit row before lookup and requires both
positions to fit in `int` before dispatching either move. This preserves
the shared selectors and prevents the invalid exchange from the editor.
Lemuria's underlying issue is tracked in `DiscoveredBugs.md` in its checkout.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_move_indexes.py -v
```

The sixteenth batch covers the Event Editor Conditions tab lookups in
`awakeFromNib`, `setForEventType:`, and `resynchChainedView`. The original
code narrowed AppKit's `NSNotFound` to `-1`, skipping the restoration
branch after returning to an event that supports conditions. Keep each
lookup in `NSInteger` and update the tab view style when a row selection
removes or restores the Conditions tab. The hosted editor verifies both
explicit event-type changes and table selection changes with real event
types. The standalone probe exercises the actual event-type setter and
asserts tab presence and style.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_tab_indexes.py -v
```

The seventeenth batch covers Event Editor table hit testing in
`eventDoubleClicked:` and `enableEvent:`. At `968d412`, the four Atlantis
warning sites in `Event Configuration Kit/EventEditor.m` are at lines 439,
440, 472, and 473. Characterize ordinary hits, misses, and synthetic
wide rows and columns before changing the actions. The original sent a
missing column to the array lookup, which raised a range exception.
Both actions now validate the signed hits before any column or event lookup.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_hit_indexes.py -v
```

The eighteenth batch covers Event Editor `moveEventUp:` and
`moveEventDown:`. At `06df675`, the two warning sites in the Atlantis
target are in `Event Configuration Kit/EventEditor.m` at lines 497
and 520. Characterize selection, responder reset, and model and table
destinations before widening the selected row. The original could truncate
a wide row onto a different event and reorder it. Validate the selected
row and destination before handing them to the collection, and preserve
the responder reset and selection of the destination. The hosted test
checks both move directions and both endpoints in the actual editor.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_reorder_indexes.py -v
```

The nineteenth batch covers Event Editor `removeCondition:` and
`removeAction:`. At `a3cc2b1`, the two warnings in the Atlantis target
are in `Event Configuration Kit/EventEditor.m` at lines 621 and 672.
Characterize event selection, chain lookup, model removal, and view
redraw before changing these actions. Lemuria's `positionOfItem:`
returns `UINT_MAX` for a missing item. The original Atlantis comparison
with `NSNotFound` missed that sentinel and could raise a range exception.
Validate the selected AppKit row, reject the sentinel, and check the
position against the model array. Redraw the action chain after removing
an action, which previously invalidated the condition chain.
The Lemuria lookup issue is tracked in `DiscoveredBugs.md`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_chain_removal_indexes.py -v
```

The twentieth batch covers the remaining Event Editor selected-row
consumers used during refresh, condition mode changes, additions, and
event removal. At `ae0c0fb` the five warnings in
`Event Configuration Kit/EventEditor.m` are at lines 321, 584, 590, 600,
and 652. Validate AppKit rows before converting them for the collection.
This also prevents the event removal path from truncating a wide row to
another event. A missing or invalid condition mode leaves the existing
mode intact.

The separate object initialization bug is recorded in
[Discovered bugs](DiscoveredBugs.md#event-creation-skips-initialization-and-loses-the-world-idle-default)
for follow-up outside warning resolution.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_selected_rows.py -v
```

The twenty-first batch covers positioned extra-data columns in the
Event Editor. At `7a7d79f`, the Atlantis warning in
`Event Configuration Kit/EventEditor.m` is at line 760. AppKit's
column lookup returns `-1` for an absent column and moving an invalid
source or destination raises an exception. Characterize normal and
synthetic column positions before editing. Keep the lookup at AppKit
width and check both indexes against the table column count before
moving the column.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_column_indexes.py -v
```

The twenty-second batch covers EventCollection count and index contracts. At
`d0c3e80`, the Atlantis warnings in `Event Configuration Kit/EventCollection.m`
are at lines 70, 80, and 85. A probe using the production methods showed
that a synthetic count of `INT_MAX + 1` becomes negative, a missing event
sends row `UINT_MAX` to the table, and a move from row 4,294,967,297
uses row 1 as its source. A count-only change restored the count, but
allowed the editor to accept row 4,294,967,297 and narrow it to row 1 at
the collection lookup. Probe sources and logs are in
`/tmp/atlantis-event-collection-review.PQiDI6`.

Use a signed full-width count for AppKit and unsigned full-width
collection positions for lookup and exchange. Preserve `NSNotFound`
and validate selection against the count before passing a signed row
to AppKit. Keep the Objective-C selectors and archive keys. The
standalone probe exercises the production collection and editor
together. The hosted editor also verifies that selecting a missing
event preserves its current selection.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_event_collection_indexes.py -v
```

The twenty-third batch covers the source positions in the two BaseEvent
move methods. At `e4e4610`, the Atlantis warnings in
`Event System/BaseEvent.m` are at lines 175 and 204. A synthetic source
of `INT_MAX + 1` became an invalid array index. A source of `UINT_MAX + 2`
could alias the destination at index 1 and suppress a valid exchange.
Retain the array's full-width source and keep the signed destination
contract used by the editor. The editor still checks both positions
before dispatching a move to Lemuria.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_base_event_move_indexes.py -v
```

The twenty-fourth batch covers the collected-conditions editor. At
`9676ce1`, the Atlantis warning in
`Event System/Conditions/Condition-CollectedConditions.m` is at line 138.
Keep the AppKit popup index signed and change the mode only for
Any or All. The original treated a missing menu selection as All.
The removal action also recognizes Lemuria's `UINT_MAX` missing
position and verifies the array bound before removing either item.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_collected_condition_indexes.py -v
```

The twenty-fifth batch covers
Computer Idle's time comparison and the idle-time helper's seconds
conversion. At `1856fb5`, the Atlantis sites are
`Event System/Conditions/Condition-ComputerIdle.m:140` and
`Utility Classes/HIDIdleTime.m:57`.

The live condition reads HID idle nanoseconds and shifts right by 30,
which divides by 1,073,741,824. The extracted conversion reports 558
seconds for 600 seconds of actual idle time. A configured 600-second
threshold first matches at 644.2450944 seconds. A subprocess exercising
the condition's eight-byte read with a one-byte datum aborted on a
Core Foundation range assertion. The separate helper already checks
the data size, but its initializer skips `IOIteratorNext` on a successful
match with a valid iterator. A stubbed IOKit success reproduced zero
iterator advances and a zero registry entry.

The replacement condition uses the repaired `HIDIdleTime` reader.
It advances a valid iterator after a successful match and releases
owned IOKit and Core Foundation objects. The reader accepts exactly
eight bytes or an exact nonnegative integer and reports failures
separately from a zero reading. The condition compares actual seconds,
including fractional thresholds, and a failed read leaves it unsatisfied.
The stored threshold remains in seconds under the same archive key.
Baseline probe sources and logs are in
`/tmp/atlantis-computer-idle-review.hs5XtN`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_computer_idle_reader.py -v
```

The twenty-sixth batch covers the String Match and Variable Match
pattern popups. At `0919fb7` the narrowing sites are at line 156 in
`Condition-StringMatch.m` and line 145 in `Condition-VariableMatch.m`.
Both actions retain the full-width menu selection and validate it
against the four pattern types before conversion. The original could
replace an existing pattern with an invalid type or truncate a wide
index to a different choice.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_condition_pattern_indexes.py -v
```

The twenty-seventh batch covers the Negated Condition child-class
lookup and popup selection. At `c621709`, the two warning sites in
`Event System/Conditions/Condition-Negate.m` are at lines 75 and 128.
The baseline regression probe truncated a synthetic index of
4,294,967,297 to index 1 in both directions and attempted to restore a
missing class at index -1. The fix preserves wide lookup and popup
indexes, skips restoration for a missing class, and bounds-checks the
popup index against the class array before lookup. The regression probe
failed on the original source and passed on the revision.

The fresh universal Debug comparison removed both narrowing sites, one
per architecture, with no new source diagnostics.
The capture in `/tmp/atlantis-negate-verified.rnD965` has 785 Atlantis warning lines
and 1,494 total. All 93 standalone tests, the numeric alias check,
and all 68 hosted smoke tests passed.

The twenty-eighth batch covers the Text Spawn copy/move menu and
attributed-text range. At `fdd69ca`, the two narrowing sites are at
lines 96 and 138 in `Event System/Actions/Action-TextSpawn.m`. The
original truncated a synthetic length of 4,294,967,297 UTF-16 code
units to 1 and treated the synthetic selection 4,294,967,296 as Copy.
Use the native Cocoa widths for both values. The same focused probe
failed on the original and passed on the revision. It checks Copy,
Move, missing selection, a wide index, empty text, and the ranges and
values written for both spawn attributes.

The fresh universal Debug comparison removed both narrowing sites on
each architecture with no new source diagnostics. The capture in
`/tmp/atlantis-text-spawn-verified.NVpOJe` has 781 Atlantis warning
lines and 1,490 total. All 94 standalone tests, the numeric alias check,
and all 68 hosted smoke tests passed.

The twenty-ninth batch covers the Set Variable action's scope popup.
At `c4ff8d6`, the narrowing site is at line 124 in
`Event System/Actions/Action-SetTempVar.m`. The popup uses rows 0–2
for `temp.`, `worldtemp.`, and `userconf.`. The original callback
replaced the stored scope with -1 or 3 for invalid selections, and
wrapped the synthetic index 4,294,967,297 to the world scope. The fix
checks the native-width index before storing the integer scope.
The regression probe verifies that rejected selections preserve the
saved scope and that valid scope values round-trip under the existing
archive key. It also checks restoration of the legacy -1 value and
the default when older archives omit the key.

The fresh universal Debug comparison removed the narrowing site for
both architectures with no new source diagnostics. The capture in
`/tmp/atlantis-set-variable-scope.z05WBy` has 779 Atlantis
warning lines and 1,488 total. All 96 standalone tests, the
numeric alias check, and all 68 hosted smoke tests passed.

The thirtieth batch covers the log export progress count. At
`a671957`, `Log System/RDLogOpener.m:157` narrows the scrollback
count from `NSUInteger` to `unsigned int`. The label displays
negative counts starting at 2³¹, and the progress maximum wraps at
2³². Preserve the Cocoa count width and format the label as unsigned.
The focused probe checks zero, 42, 2³¹, and 2³² + 1 against both the
label and the progress maximum.

The probe failed on `a671957` and passed after the fix. The fresh
universal Debug build removed the narrowing warning on arm64 and
x86_64 with no new source diagnostics. The build had 777 Atlantis
warning lines and 1,538 total, including 52 Xcode environment warnings.
All 97 standalone tests, the numeric alias check, and all 68 hosted
smoke tests passed.

Batch 31 covers formatted-log wrapping. The narrowing warning at
`Log System/RDFormattedText.m:345` is in the formatted-log wrapping
loop. A probe of the production method with `abcdef` confirmed that
margin 4 and indent 2 emit `abc-` followed by `  ef`, dropping
`d` at the hard wrap. Margin 4 and indent 4, or margin 11 with
timestamps enabled, raise `NSInvalidArgumentException` because the
available width is zero and subtracting the hyphen width underflows.
The fix keeps UTF-16 units for the margin and uses Foundation's
composed-character boundaries for breaks. Hard wraps resume at the
first source character beyond the slice. When the margin leaves no
usable width, the writer emits the remaining text unwrapped. When a
whole grapheme cannot fit alongside a hyphen, the writer emits the
grapheme whole and omits the hyphen.

The focused probe in
`Tests/WarningResolution/test_formatted_log_wrap.py` runs the same
production writer against the original and revised code. It checks
exact UTF-8 output for soft and hard wraps, unusable and one-unit
widths, timestamp prefixes, and surrogate pairs, combining marks,
and joined emoji. Nine of its eleven cases failed on `fe59a1c`.
All eleven pass after the fix.

The fresh universal Debug build removed the narrowing warning on
arm64 and x86_64 without adding source diagnostics. The capture has
775 Atlantis warning lines and 1,536 total, including 52 Xcode
environment warnings. All 98 standalone tests and the numeric alias
check passed. All 68 hosted smoke tests passed on Intel.

Batch 32 covers the settings dialogs in `RDFormattedText.m:132` and
`RDHTMLLog.m:182` at `6f2c8bd`. They both accept the dialog's own
response code 1 and keep existing options for other responses.
The 32-bit local converted synthetic responses `4294967297` and
`-4294967295` into 1, applying settings for an unrelated response.
Use `NSModalResponse` from AppKit for both results. The same focused
probe verifies acceptance, cancellation, abort, and both wide
responses before and after the change.

The fresh universal Debug build removed both warnings on arm64 and
x86_64 with no new source diagnostics. The capture has 771 Atlantis
warning lines and 1,532 total, including 52 Xcode environment
warnings. All 99 standalone tests and the numeric alias check passed.
All 68 hosted smoke tests passed on Intel.

Batch 33 covers the log save panel. At `00bea17`, the legacy
overwrite alert at `RDLogOpener.m:329` narrowed `NSModalResponse`
to `int`. An isolated probe of
the production save-panel delegate with a fake file manager confirms
that a synthetic response of `4294967297` selects Replace. It also
shows that ordinary Replace removes the original file during filename
validation, before the logger opens it, and ordinary Append returns
the filename even when moving the existing log fails. The save
completion ignores the result of the move back into place and has no
recovery on failure to open the logger. The original probe source
and output are in `/tmp/atlantis-log-modal.dnvcYz`.

The save-panel completion now uses the final URL and full-width modal
responses. For an existing regular file, Atlantis asks for an explicit
action, with Cancel as the default. Append opens the confirmed file
in place and validates the descriptor's identity. Replace prepares
and flushes the new logger in a private sibling file. It then swaps
the two names atomically. The logger keeps the prepared descriptor,
and Atlantis removes the displaced file only after confirming its
identity and metadata. If a competing change is detected after the
swap, Atlantis attempts to restore the displaced file and reports its
recovery path if restoration fails. New log files use exclusive
publication so a file that appears during preparation stays intact.
The logger uses cooperative locks to reject save-panel operations on
an active log. The existing event action opens files without truncating
them and reports an open failure before registering the logger.

The overwrite-response probe checks that Cancel, an abort, and an
unexpected wide response authorize no operation. Hosted tests use
disposable files and assert exact bytes before and after preparation,
on a failed preparation, and on an actual failed swap with an
immutable original. They also cover an intervening writer, exclusive
creation, append in place, a missing append target, an active log,
and cleanup after an unrelated file takes the staging name.

The fresh universal Debug build removed 12 warning sites across
arm64 and x86_64, with no new source diagnostics. It has 747 Atlantis
warning lines and 1,508 total. All 100 standalone tests, the numeric
alias check, and all 75 Intel hosted smoke tests passed on the final
run. The first hosted run passed the log cases but failed
`RDAtlantisSpawnTests.testCommittedInputAddsPrefixOnce`, which passed
on rerun.

Batch 34 covers the world editor's Keepalive popup. At `1969b9a`,
`Preferences/World/WorldMainEditor.m:161` and `:226` narrowed
AppKit's selected index to an `int`. Both save paths persisted
missing selection as `-1`, and a synthetic index of `4294967297`
was saved as row 1. The popup now validates the native-width
selection before saving, and final commit calls the same action.
Restoration checks saved values at native width and displays the
existing row-0 default for invalid or absent values. The preference
key, valid mode values, and Telnet consumers retain their existing
contract.

The focused `Tests/WarningResolution/test_world_keepalive_selection.py`
probe checks both save paths and restoration for rows 0–3,
missing and out-of-range selections, a synthetic wide value, and an
absent preference. The same assertions failed on `1969b9a` and
passed on the revision.

The fresh universal Debug build removed both warning sites on arm64
and x86_64 and added no source diagnostics. It has 743 Atlantis
warning lines and 1,504 total. All 101 standalone tests and the
numeric alias check passed.

All 76 hosted smoke tests passed on Intel, including the pending
spawn input diagnostic test in the working tree.

Batch 35 covers the world editor's Server Type popup. At `cc48db6`,
`Preferences/World/WorldMainEditor.m:260` and `:270` narrowed the
selected index to an `int`. Both save paths persisted missing
selection as `-1`. A synthetic index of `4294967297` selected
the MUD mode and, in the change handler, set its 500-line scrollback
default. Both paths now share native-width selection validation.
Invalid or absent saved values display the nib's row-0 default.
Only a valid MUD selection in the change handler initializes
scrollback, and it preserves an existing value. Character editors
continue to leave these world-level preferences alone.

The focused `Tests/WarningResolution/test_world_server_type_selection.py`
probe checks valid, missing, out-of-range, and wide values through
both save paths and restoration. It also checks the MUD scrollback
default, preservation of an existing override, and character editing.
The same assertions failed on `cc48db6` and passed after the fix.

The fresh universal Debug build removed both warning sites on arm64
and x86_64, with no new source diagnostics. It has 739 Atlantis
warning lines and 1,500 total. All 102 standalone tests and the
numeric alias check passed. All 76 hosted smoke tests passed on Intel,
including the pending spawn input diagnostic test in the working tree.

Batch 36 covers the world editor's startup checkbox and popup.
At `cdd43e7`, the six narrowing warnings in
`Preferences/World/WorldMainEditor.m` are at lines 134, 136, 170,
173, 255, and 257. A missing or out-of-range popup index previously
enabled autoconnect, and a checkbox value of `4294967297` was
treated as On. Both actions and final save now use native-width
AppKit values and share preference writes. When the checkbox is
On, the popup must select row 0 or 1. Invalid selections preserve
the saved mode. Open sets only auto-open, and Open and Connect sets
autoconnect while retaining the existing auto-open value. Turning
the checkbox off clears both flags. The startup code gives
autoconnect priority for both worlds and characters.

The production-method probe exercises both actions and the startup
part of final save across 72 cases. Twenty-nine failed on
`cdd43e7`, and all pass after the fix.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_world_autoconnect_selection.py -v
```

The fresh universal Debug build removed all six sites on arm64 and
x86_64 without adding app diagnostics. Atlantis app warnings fell
from 739 to 727, with 63 distinct narrowing sites remaining. Lemuria
stayed at 698. The hosted build log additionally includes 30
test-target warning lines. All 103 standalone tests, the numeric
alias check, and all 76 Intel hosted smoke tests passed.

Batch 37 covers the SSL checkbox in the world editor's final save.
At `3ec19ea`, `Preferences/World/WorldMainEditor.m:216` narrowed
`NSControlStateValue` to `int`. The final save treated the synthetic
state `4294967297` as On while the interactive action saved false.
The final save now uses that same action when the checkbox is enabled.
A disabled checkbox still clears the local SSL override so preference
inheritance can apply. The focused probe exercises both paths,
including Off, On, Mixed, a wide value, and disabled inheritance. It
failed on the original save and passes after the change.

Certificate trust for direct TLS is tracked as
[separate work](DiscoveredBugs.md#review-certificate-trust-for-direct-tls-connections).

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_world_ssl_selection.py -v
```

The fresh arm64 and x86_64 Debug build removed the warning on both
architectures. Atlantis app warning lines fell from 727 to 725. The
hosted build captured 755 Atlantis warning lines and 1,463 total,
with no new source diagnostics. All 104 standalone tests, the
numeric alias check, and all 76 Intel hosted smoke tests passed.

Batch 38 covers quit confirmation with connected worlds.
At `e3b5fa6`, `Core/RDAtlantisMainController.m:1422` narrowed
AppKit's `NSModalResponse` to `int`. The legacy alert constructor
uses the `NSAlertDefaultReturn` family, as documented by the SDK.
The old delegate proceeded on an abort, an alert error, or an
unexpected response, including a wide value that aliases Quit.
The delegate now uses the full-width response and disconnects
worlds only for the alert's exact Quit response. Escape still
cancels, and quitting without connected worlds needs no alert.

The focused probe compiles the production termination delegate
and verifies its reply, save, disconnect, and alert calls.
The original failed for three unexpected responses, and all
twelve cases pass after the fix.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_quit_confirmation.py -v
```

The fresh universal Debug build removed the narrowing on arm64 and
x86_64. The existing legacy response deprecation now names
`NSAlertDefaultReturn`. The hosted build captured 753 Atlantis warning
lines (723 app lines) and 1,461 total. All 105 standalone tests, the
numeric alias check, and all 76 Intel hosted smoke tests passed.

Batch 39 covers the stored startup version. At `8d2b650`,
`Core/RDAtlantisMainController.m:271` narrowed the value returned by
`integerForKey:` to `int`. A synthetic stored version of `4294967296`
became zero and reached the standard preferences reset. Use
`NSInteger` for the stored value and retain the zero-version
reset and named-profile guard. The focused test uses a disposable
defaults suite and intercepts the reset branch. The original failed
for the synthetic version and the revised guard passes all ten
cases, including explicit zero and a missing version with other
settings present.

Future investigation of old preference formats and a possible reset
prompt is tracked in [Discovered Bugs](DiscoveredBugs.md#investigate-the-zero-version-startup-preferences-reset).

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_startup_version.py -v
```

The universal Debug build removed the narrowing on both architectures
with no new source diagnostics. It captured 751 Atlantis warning lines
(721 app lines) and 1,459 total. All 106 standalone tests, the numeric
alias check, and all 76 Intel hosted smoke tests passed.

Batch 40 covers the Action and Condition registry count getters.
At `1305f4e`, both methods narrowed the backing array's
`NSUInteger` count to `unsigned` at line 50 of `ActionClasses.m`
and `ConditionClasses.m`. The selectors have no in-tree callers.
The declarations and implementations now return `NSUInteger`.
The focused test compiles each getter against its actual header and
checks the runtime return width and empty, ordinary, and wide counts.
Both baseline getters returned 1 for a synthetic count of 4294967297.
Both revised getters return the full count.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_registry_counts.py -v
```

The universal Debug build removed both narrowing warnings on arm64
and x86_64 with no new source diagnostics. It captured 1,455 warning
lines, including 747 Atlantis lines after rejoining a split compiler
diagnostic. All 107 standalone tests, the numeric alias check, and
all 76 Intel hosted smoke tests passed.

Batch 41 covers view-weight path splitting. At `b3ed18e`,
`Core/RDAtlantisMainController.m:873` narrowed the start of the spawn
substring from `NSUInteger` to `int`. Keep the start at Foundation
range width. The focused probe verifies real root, nested, and unknown
paths, plus a synthetic separator beyond the 32-bit boundary. Only the
wide path fails on the original. The revised method passes all cases,
including the existing zero result without a live instance and the lack
of a saved preference lookup.

The unreachable saved world-weight fallback is tracked
[for later investigation](DiscoveredBugs.md#investigate-the-unreachable-saved-view-weight-fallback).

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_view_weight_range.py -v
```

The universal Debug build removed the warning on arm64 and x86_64,
with no new source diagnostics after normalizing the split diagnostic
in the baseline. It captured 745 Atlantis warning lines (715 app lines)
and 1,453 total. All 108 standalone tests, the numeric alias check,
and all 76 Intel hosted smoke tests passed.

Batch 42 covers the Dock badge active-view count. At `8b64b19`,
`Core/RDAtlantisMainController.m:1777` narrowed the count to `int`.
The badge disappeared at synthetic counts of 2³¹ and 2³², and 2³² + 1
displayed as 1. Preserve the collection's `NSUInteger` count and format
it as unsigned decimal. The focused probe compares exact labels and
checks the existing inactive-only and visible-window rules without
changing system settings. The expected wide labels fail on the
baseline and pass after the fix.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tests/WarningResolution/test_dock_badge_count.py -v
```

The universal Debug build removed the warning on arm64 and x86_64,
with no new source diagnostics. It captured 743 Atlantis warning lines
(713 app lines) and 1,451 total. All 109 standalone tests, the numeric
alias check, and all 76 Intel hosted smoke tests passed.

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
