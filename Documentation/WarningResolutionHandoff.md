# Atlantis warning resolution handoff

## Current state

- Branch `warning-resolution` starts from `main` at `ee9deed`
  (`feat(telnet): prefer UTF-8 in CHARSET`).
- The [warning resolution workplan](WarningResolutionWorkplan.md) has a
  fresh warning capture and an automated application smoke baseline.
  The first increment is committed at `b5836e8`. The second increment
  is committed at `f576972`. The picker batch is committed at
  `49330c1`, the editor batch at `76b2a75`, and the log-closing table batch
  at `cc5291e`. The User Variables batch is committed at `afe6dc5` and
  the Highlights batch at `659e515`. The shared outline click batch is
  committed at `62a75f0`, the Spawn outline batch at `2e26532`, and the
  Spawn table batch at `66ef54e`, and the Spawn removal batch at
  `734abb6`. The Address Book outline data-source batch is committed at
  `adecaa0`, the selection batch at `2b40fd4`, and the add and focus
  batch at `8f4b35a`, and the column and tab lookup batch at `b593707`.
  The Event Editor table data-source batch is committed at `c3ae6e1`.
- The Event Editor move batch is committed at `909740a`, the
  Conditions tab batch at `968d412`, hit testing at `06df675`,
  whole-event reordering at `a3cc2b1`, chain removal at `ae0c0fb`,
  selected-row checks at `7a7d79f`, and extra-data columns at
  `d0c3e80`. EventCollection is committed at `e4e4610` and BaseEvent
  move indexes at `9676ce1`. The collected-conditions batch is committed
  at `1856fb5` and Computer Idle at `0919fb7`. The twenty-sixth batch
  checks the String Match and Variable Match pattern menus. Its universal
  Debug capture has 789 Atlantis warning lines and 1,550 total.
  Artifacts are in `/tmp/atlantis-increment3-condition-patterns.I5lKJG`.
- The Negated Condition batch is committed at `fdd69ca`. Its universal
  Debug capture has 785 Atlantis warning lines and 1,494 total. Artifacts
  are in `/tmp/atlantis-negate-verified.rnD965`.
- The Text Spawn batch is committed at `c4ff8d6`. Its universal
  Debug capture has 781 Atlantis warning lines and 1,490 total. Artifacts
  are in `/tmp/atlantis-text-spawn-verified.NVpOJe`.
- The twenty-ninth batch covers the Set Variable action's scope popup.
  Its universal Debug capture has 779 Atlantis warning lines and
  1,488 total. Artifacts are in `/tmp/atlantis-set-variable-scope.z05WBy`.
- Review the remaining AppKit index and count warnings before selecting
  the next batch.
- The generated change in `English.lproj/InfoPlist.strings` predates this
  effort. Preserve its pre-build diff and stage only explicit task files.
- Scope is Atlantis source, resources, and project settings. Lemuria
  remains in the build for integration coverage.

## Build baseline

The Debug build succeeded on 2026-11-26 using full Xcode, the shared
`Atlantis` scheme, the macOS destination, signing disabled, and a new
Derived Data directory. The capture contains 2,182 warning lines including
repeats, dependency warnings, and Xcode diagnostics. By path, 1,421 are
Atlantis and 698 are Lemuria. Project-level warnings can lack a source path.

The local artifacts are in `/tmp/atlantis-warning-resolution.HMegBN`:

- `build.log` has the full build output and diagnostic context.
- `warnings.log` lists captured warning lines with the original line numbers.
- `warnings-by-group.tsv` identifies the group and origin for each line.

These files are temporary. If unavailable, regenerate the baseline at
`ee9deed` in a fresh Derived Data directory using the same configuration
and record any Xcode or SDK difference before comparing counts.

## First-increment results

The original implementation returned the expected HID idle time for numeric
values and exact-size data, and accepted oversized data. The revised code
preserves both valid paths and rejects short and oversized payloads. The
invalid-regex path still returns no match and now logs the original pattern
with its percent signs intact.

The MCP multiline message probe compared exact UTF-8 bytes across the
four-digit hex boundary. It also verified the entry at `ffffffff` and the
next entry, which now emits `100000000` across the header, continuations,
and terminator. The session-key, connected-time, idle-description, and
alert probes exercised the production formatting expressions with
deterministic inputs. They verified whole elapsed seconds beyond the
32-bit range, a fractional idle threshold, whole reference-date seconds
for the session key, and matching text with a literal percent sign in both
AppKit alerts.

The hosted Open Log test passed against the original code. It opens the
real configuration view and checks the Options button on initial load,
after switching between Plain Text and Plain Text (Formatted), and after
refreshing the view.

The fresh universal Debug build used Xcode 26.6 (17F113) and the macOS
26.5 SDK. It removed all 20 planned warning lines and the two architecture
repeats for the HID copy method. The Atlantis count fell from 1,421 to
1,399 and the raw count fell from 2,182 to 2,160. No new source diagnostics
appeared. Lemuria stayed at 698, Xcode environment at 52, diagnostic echoes
at 6, and pathless diagnostics at 5.

The build log, numbered warning extract, source comparison, and focused
probe logs are in `/tmp/atlantis-increment1.4Qs2hz`.

The current-user smoke suite passed all 58 selected tests before and after
the changes, including the new Open Log check. XCTest ran on Intel. The
`smoke-before` and `smoke-after` directories under the same artifact
directory contain the result bundles, captures, and test logs.

The seven standalone format tests passed for the first-increment changes.
The same harness rejected all seven original format calls at compile time
on the pre-increment revision, `7b16ab8`. The
[workplan](WarningResolutionWorkplan.md#first-increment-behavior) records
the command. The temporary probe logs retain the before-and-after output
observations.

## Second-increment results

The comparison baseline is `2bbe48d`, which retains the first increment's
app sources and warning capture. The second increment replaces 15 distinct
numeric AppKit aliases. An SDK check verified equal values for all 15 and
compatible expression types for 13. The two legacy modal constants have
type `int` and the replacements use `NSModalResponse`. Their values and
the comparisons and arguments at the Atlantis call sites are preserved.
The check compiled for arm64 and x86_64 and ran on Intel.

The 18 literal simplifications preserve the original string contents,
including MUSH escaping, with ownership operations intact. The removed
XML local had a constant initializer and no reads. The pasteboard
replacement and the MCP editor initializer are deferred as described in
the [workplan](WarningResolutionWorkplan.md#second-increment-scope).

To reproduce the numeric alias check from the repository root, run:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
alias_dir="$(mktemp -d /tmp/atlantis-alias-check.XXXXXX)"
xcrun clang -arch arm64 -arch x86_64 -Wno-deprecated-declarations \
  -framework AppKit -framework Foundation Tests/WarningResolution/warning_constant_aliases.m \
  -o "$alias_dir/warning-constant-aliases"
"$alias_dir/warning-constant-aliases"
```

The fresh Debug build compiled for arm64 and x86_64 with Xcode 26.6
(17F113) and the macOS 26.5 SDK. It removed 418 warning lines across 209
source sites. Atlantis dropped from 1,399 to 981 lines and the raw count
dropped from 2,160 to 1,742. Lemuria stayed at 698 and the other diagnostic
counts were unchanged. The comparison rejoined one split XIB diagnostic
to match the existing baseline warning. No new source diagnostics remained.

The seven standalone format checks passed on both the baseline sources
and the second-increment sources. The current-user application smoke suite
passed all 58 selected tests on Intel, matching the first-increment run.
The build log, numbered warning extracts, comparison, focused check logs,
and hosted test artifacts are in `/tmp/atlantis-increment2.jacwyS`.

## Third increment, picker indexes

The source baseline is `4ed1986`, which retains the second increment's
application sources. Both picker callbacks now use AppKit's signed
selection index directly and check it against the backing array before
looking up a class or calling the delegate.

The [standalone picker tests](../Tests/WarningResolution/test_picker_indexes.py)
compile both production callbacks with synthetic menus and class arrays.
On the baseline, ordinary selections passed for both pickers. Ten
subcases failed because the old callbacks truncated the wide index or
attempted an invalid lookup. On the revised sources, all four tests
passed for both pickers. The cases include a valid index above
`UINT32_MAX`, `-1`, `NSNotFound` with a normal array count, an empty
array, and an index equal to the array count.

The [workplan](WarningResolutionWorkplan.md#third-increment-batches)
records the test command. Before-and-after logs are in
`/tmp/atlantis-increment3-pickers.3ldSoW`.

The fresh universal Debug build removed both picker warning sites across
arm64 and x86_64. Atlantis warning lines fell from 981 to 977 and the raw
count fell from 1,742 to 1,738. The comparison found no new source
diagnostics. The build log, numbered warning extract, and comparison are
in the same artifact directory. All 11 Python-driven standalone tests
passed, including the seven existing format tests.
The current-user hosted smoke suite passed all 58 selected tests on Intel.
Its capture and XCTest result bundle are in the `smoke` subdirectory.

## Third increment, editor indexes

The baseline is picker-batch commit `49330c1`. World Configuration and
Open Log now keep AppKit indexes at full width. World Configuration skips
the commit when there is no current tab. Open Log ignores a missing or
out-of-range format selection and preserves the existing default when
restoring the format menu.

The [standalone editor tests](../Tests/WarningResolution/test_editor_indexes.py)
compile the three production methods with synthetic selections and
collections. The baseline preserved ordinary selections and already
skipped the tab commit for an invalid index. Seven subcases failed on
the baseline because the methods truncated wide indexes or Open Log
attempted an invalid lookup. All five editor tests passed on the revised
sources, along with the eleven existing Python tests.

The [workplan](WarningResolutionWorkplan.md#third-increment-batches)
records the test command. Logs are in
`/tmp/atlantis-increment3-editors.gjQ8r6`.

The fresh universal Debug build removed three narrowing warning sites
across arm64 and x86_64. Atlantis warning lines fell from 977 to 971 and
the raw count fell from 1,738 to 1,732. The comparison found no new
source diagnostics. The build log, numbered warning extract, and
comparison are in the same artifact directory.

The current-user hosted smoke suite passed all 58 selected tests on
Intel, including the Open Log format and World Configuration tab
checks. The `smoke` subdirectory contains the capture and result bundle.

## Third increment, log-closing table indexes

The baseline is editor-batch commit `76b2a75`. The log-closing table data
source now matches the AppKit protocol's `NSInteger` return and row
parameter types. Row labels retain their zero-based decimal format.
Closing a selected log already used `NSUInteger` indexes.

The [standalone log-closer tests](../Tests/WarningResolution/test_log_closer_indexes.py)
compile the production data-source and close methods with a synthetic
log collection. On the baseline, the empty and ordinary row cases
passed. The runtime signatures disagreed with AppKit and the wide row
truncated in the row label and metadata lookup. On the revised sources,
all four tests passed, including the selected-log close and removal
assertions. All 20 Python standalone tests passed.

The [workplan](WarningResolutionWorkplan.md#third-increment-batches)
records the run command. Before-and-after logs are in
`/tmp/atlantis-increment3-log-closer.D5Y9Ps`.

The fresh arm64 and x86_64 Debug build removed three warning sites,
including the row-count narrowing and both protocol signature
mismatches. Atlantis warning lines fell from 971 to 965 and the raw
count fell from 1,732 to 1,726. The comparison found no new source
diagnostics. Build logs and the numbered warning extract are in the
same artifact directory.

All 58 current-user hosted smoke tests passed on Intel. The `smoke`
subdirectory contains the capture and XCTest result bundle.

## Third increment, User Variables table indexes

The baseline is log-closing batch commit `cc5291e`. The User Variables
table uses AppKit's signed `NSInteger` row count and row parameters. Add
Variable passes the full-width index of the new row when selecting it and
starting inline editing. The existing removal action already checks for a
missing or out-of-range selection before looking up the variable.

The [standalone User Variables tests](../Tests/WarningResolution/test_user_variable_indexes.py)
compile the production callbacks and Add action with synthetic row counts.
The original code passed the empty and ordinary cases. Its runtime
signatures disagreed with AppKit, and it truncated wide indexes during
lookup, editing, and selection. All four cases passed after the change.
All 24 Python standalone tests and the numeric alias check passed.

The [workplan](WarningResolutionWorkplan.md#third-increment-batches)
records the test command. Artifacts are in
`/tmp/atlantis-increment3-user-variables.4JH5MQ`.

The fresh Debug build used Xcode 26.6 (17F113) and the macOS 26.5 SDK
for arm64 and x86_64. It removed five warning sites across both
architectures. Atlantis warning lines fell from 965 to 955 and the raw
count fell from 1,726 to 1,716. There were no new source diagnostics.
Use this capture as the comparison baseline for the next batch.

The hosted test target built successfully. The first smoke attempt could
not reach the XCTest service from the sandbox. The current-user run
passed all 58 selected tests on Intel, including the User Variables
check for no selection before Add and selection of the new row after Add.
The capture, test log, and result bundle are in `smoke-current-user`.

## Third increment, Highlights table indexes

The baseline is User Variables batch commit `afe6dc5`. The Highlights
table data-source callbacks now match AppKit's signed row types. The
selection delegate and the pattern and color actions use full-width row
indexes. Add Highlight checks `NSNotFound` at the array lookup before
passing the index to AppKit. The pattern popup preserves the current
pattern when its selection is outside the four supported pattern types.
The removal confirmation already used full-width indexes.

The [standalone Highlights tests](../Tests/WarningResolution/test_highlight_indexes.py)
compile the production table and action methods with synthetic indexes.
All four normal menu choices passed on the baseline. Six baseline
subcases failed across the runtime signatures, wide rows, the missing
Add index, and invalid menu selections. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) records
the test command. Artifacts are in
`/tmp/atlantis-increment3-highlights.sxCEEb`.

All five focused tests passed after the change, and all 29 Python
standalone tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed 12 warning sites. Atlantis warning lines fell from
955 to 931 and the raw count fell from 1,716 to 1,692. The comparison
found no new source diagnostics. Use this capture as the baseline for the
next batch.

The hosted test target built successfully. All 58 selected smoke tests
passed on Intel with a disposable profile. The hosted Highlights test
checked no selection, selection after Add, and canceling and confirming
removal. The capture, test log, and result bundle are in
`smoke-current-user`.

## Third increment, outline click indexes

The baseline is Highlights batch commit `659e515`. The shared outline
view used by the Address Book and Spawn editor preserves the signed
row and column indexes from AppKit hit testing. The custom click
delegate runs only when the click hits both a row and a column.
Clicks outside a cell and mouse drags continue through AppKit.

The [standalone outline click tests](../Tests/WarningResolution/test_outline_click_indexes.py)
compile the production mouse handler with synthetic events and indexes.
The baseline passed the ordinary click, drag, and missing-row cases.
It truncated both wide indexes and tried to look up a column when
AppKit returned its missing-column sentinel. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) records
the test command. Artifacts are in
`/tmp/atlantis-increment3-outline-clicks.xLOOi8`.

All four focused tests passed after the change. All 33 Python
standalone tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed both warning sites. Atlantis warning lines fell
from 931 to 927 and the raw count fell from 1,692 to 1,688. The
comparison found no new source diagnostics. Use this capture as the
baseline for the next batch.

The hosted test target built successfully. All 59 selected smoke tests
passed on Intel, including the new test that clicks the hosted Spawn
outline and checks the item and column delivered to its delegate.
The capture, test log, and result bundle are in `smoke-current-user`.

## Third increment, Spawn editor outline indexes

The baseline is shared outline click batch commit `62a75f0`. The Spawn
outline data-source signatures now match AppKit. Child lookup retains
the branch bounds check. Reading and restoring the selection and
selecting an added spawn now retain full-width row indexes.

The [standalone Spawn outline tests](../Tests/WarningResolution/test_spawn_outline_indexes.py)
compile the production callbacks and actions with synthetic indexes.
The baseline preserved ordinary rows and the missing and out-of-range
cases. The signature check and the wide-index subcase failed on the
baseline. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) records
the test command. Artifacts are in
`/tmp/atlantis-increment3-spawn-outline.WPjSfq`.

All five focused tests passed after the change, and all 38 Python
standalone tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed eight warning sites. Atlantis warning lines
fell from 927 to 911 and the raw count fell from 1,688 to 1,672. The
comparison rejoined a split Formatting XIB diagnostic and found no new
source diagnostics. Use this capture as the baseline for the next batch.

The hosted test target built successfully. All 60 selected smoke tests
passed on Intel, including the new test that adds and renames a spawn
and verifies that the same item stays selected after the outline reloads.
The capture, test log, and result bundle are in `smoke-current-user`.

## Third increment, Spawn pattern and exception table indexes

The baseline is Spawn outline batch commit `2e26532`. Both tables now
use AppKit's signed row types in their data-source methods. Add preserves
the array lookup index and checks the missing sentinel before selecting
and editing the row. Remove validates the selected row at full width
before making a mutable copy.

The [standalone Spawn table tests](../Tests/WarningResolution/test_spawn_pattern_indexes.py)
compile the production callbacks and actions with synthetic indexes.
The baseline passed ordinary reads, edits, and actions. Nine subcases
failed across the protocol signatures, wide rows, and the missing
index after Add. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) records
the test command. Artifacts are in
`/tmp/atlantis-increment3-spawn-patterns.o1NTfP`.

All six focused tests passed after the change. All 44 Python standalone
tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed eight warning sites. Atlantis warning lines
fell from 911 to 895 and the raw count fell from 1,672 to 1,656. The
comparison found no new source diagnostics. Use this capture as the
baseline for the next batch.

The first hosted run showed that the test had to select each tab before
locating its controls. After that correction, all 61 selected smoke
tests passed on Intel. The new hosted test added, edited, and removed
a row on each tab. The capture, test log, and result bundle are in
`smoke-final`.

## Third increment, Spawn removal sheet row index

The baseline is Spawn table batch commit `66ef54e`. The selected row
is boxed and read as `NSInteger`, and the callback releases its context
after using it. A detached editor skips opening the sheet.

The [standalone Spawn removal tests](../Tests/WarningResolution/test_spawn_removal_indexes.py)
run the production action and callback across an autorelease pool
boundary. The original code passed ordinary confirmation, cancellation,
and missing selection. It truncated both wide rows to row 2 and tried
to start a sheet in the detached case. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) records
the test command. Artifacts are in
`/tmp/atlantis-increment3-spawn-removal.BZN1Ln`.

All three focused tests passed after the change. All 47 Python
standalone tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed the row narrowing warning on both
architectures. Atlantis warning lines fell from 895 to 893 and the raw
count fell from 1,656 to 1,654. The comparison found no new source
diagnostics. Use this capture as the baseline for the next batch.

The hosted test target built successfully. All 62 selected smoke tests
passed on Intel. The new test pressed No and then Yes on the actual
Spawn removal sheet and verified that only confirmation removed the
selected spawn. The capture, test log, and result bundle are in
`smoke-current-user`.

## Third increment, Address Book outline data-source indexes

The baseline is Spawn removal batch commit `734abb6`. The Address Book
data source now matches AppKit's signed child count and index signatures
for top-level worlds and character rows. Child lookup validates the
full-width index against the relevant collection.

The [standalone Address Book tests](../Tests/WarningResolution/test_address_book_outline_indexes.py)
compile the production callbacks with synthetic world and character
collections. The baseline passed ordinary, empty, and missing cases.
Three subcases failed across the signatures, wide lookup, and wide
out-of-range lookup. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) records
the test command. Artifacts are in
`/tmp/atlantis-increment3-address-book-outline.ETrX3P`.

All three focused tests passed after the change. All 50 Python
standalone tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed four warning sites. Atlantis warning lines
fell from 893 to 885 and the raw count fell from 1,654 to 1,646.
The comparison found no new source diagnostics. Use this capture as
the baseline for the next batch.

The hosted test target built successfully. All 63 selected smoke tests
passed on Intel. The new test loaded the actual Address Book nib with
an empty collection, added a fixture world, and verified its character
row on expansion and collapse. The capture, test log, and result bundle
are in `smoke-current-user`.

## Third increment, Address Book selection and tab indexes

The baseline is Address Book data-source batch commit `adecaa0`. The
selection actions and outline reload keep full-width row indexes. A
selected editor tab is carried between records when the destination
contains the index. An unavailable tab leaves the destination editor's
selection intact.

The [standalone Address Book selection tests](../Tests/WarningResolution/test_address_book_selection_indexes.py)
compile the production methods with synthetic outline rows and tabs.
The baseline passed ordinary selection, missing outline selection, and
a missing row after reload. Six subcases failed across wide indexes and
tabs that could not be restored. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) records
the test command. Artifacts are in
`/tmp/atlantis-increment3-address-book-selection.ZEPgep`.

All three focused tests passed after the change. All 53 Python
standalone tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed five warning sites. Atlantis warning lines
fell from 885 to 875 and the raw count fell from 1,646 to 1,636.
The comparison found no new source diagnostics. Use this capture as
the baseline for the next batch.

The hosted test target built successfully. All 64 selected smoke tests
passed on Intel. The new test switched between a world and character
and verified restoration of a shared tab and preservation of the
destination selection when a source tab had no counterpart. The capture,
test log, and result bundle are in `smoke-current-user`.

## Third increment, Address Book add and focus row indexes

The baseline is Address Book selection batch commit `2b40fd4`.
Add World, Add Character, and Focus World now keep AppKit's signed row
index through selection. They leave the selection alone when the row
lookup returns `-1`.

The [standalone Address Book action tests](../Tests/WarningResolution/test_address_book_action_indexes.py)
compile the production actions with synthetic row lookups. The baseline
passed ordinary and missing rows. All four wide-row subcases truncated
the result. The [workplan](WarningResolutionWorkplan.md#third-increment-batches)
records the command. Artifacts are in
`/tmp/atlantis-increment3-address-book-actions.R4ipKj`.

Both focused tests passed after the change. All 55 Python standalone
tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed three warning sites. Atlantis warning lines
fell from 875 to 869 and the raw count fell from 1,636 to 1,630.
The comparison found no new source diagnostics. Use this capture as
the baseline for the next batch.

The hosted test target built successfully. All 65 selected smoke tests
passed on Intel. The new test verified that Add World, Add Character,
and Focus World each selected the intended record in a disposable
Address Book. The capture, test log, and result bundle are in
`smoke-current-user`.

## Third increment, Address Book column and tab lookup indexes

The baseline is Address Book add and focus batch commit `8f4b35a`.
The connection column lookup checks the array's `NSNotFound` before
converting the index for AppKit. The editor tab lookup keeps AppKit's
signed index and adds a tab when the lookup reports a missing item.

The [standalone Address Book lookup tests](../Tests/WarningResolution/test_address_book_lookup_indexes.py)
compile the production lookups with synthetic indexes. The baseline
passed ordinary lookups and added a tab in the missing-tab cases.
Three subcases failed across the missing column and wide column and tab
indexes. The [workplan](WarningResolutionWorkplan.md#third-increment-batches)
records the command. Artifacts are in
`/tmp/atlantis-increment3-address-book-lookups.N5liwd`.

All four focused tests passed after the change. All 59 Python
standalone tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed both warning sites. Atlantis warning lines
fell from 869 to 865 and the raw count fell from 1,630 to 1,626.
The comparison found no new source diagnostics. Use this capture as
the baseline for the next batch.

The hosted test target built successfully. All 66 selected smoke tests
passed on Intel. The new test verified the first connection column and
one selected editor tab after adding a character. The capture, test log,
and result bundle are in `smoke-current-user`.

## Third increment, Event Editor table data-source indexes

The baseline is Address Book lookup batch commit `b593707`. The Event
Editor uses AppKit's signed row count and row parameters. Both data
callbacks check the row against the collection count before converting
it to the collection's unsigned index type.

The [standalone Event Editor table tests](../Tests/WarningResolution/test_event_table_indexes.py)
compile the production callbacks. The baseline passed ordinary edits
and ignored an unrelated table. Five subcases failed across the runtime
signatures and invalid row lookups. Artifacts are in
`/tmp/atlantis-increment3-event-table.kWUVYs`.

All four focused tests passed after the change. All 63 Python standalone
tests and the numeric alias check passed. The fresh arm64 and x86_64
Debug build used Xcode 26.6 (17F113) and the macOS 26.5 SDK. It removed
three warning sites. Atlantis warning lines fell from 865 to 859, and
the raw count fell from 1,626 to 1,620. No new source diagnostics
appeared. Use this capture as the baseline for the next batch.

All 66 selected hosted smoke tests passed on Intel. The Event Editor
test verified an ordinary name edit and that a row above the 32-bit
range could not edit that event. The capture, test log, and result bundle
are in `smoke-current-user`.

## Third increment, Event Editor move indexes

The baseline is Event Editor table batch commit `c3ae6e1`. The move
actions validate the selected row before event lookup and keep the chain
position at full width until both source and destination fit the existing
signed move APIs. A synthetic probe of both original `BaseEvent` methods
showed that a source of `INT_MAX + 1` became an out-of-bounds array index
when moving up to `INT_MAX`. Lemuria uses the same source conversion in
its view implementation. See `DiscoveredBugs.md` in the Lemuria checkout.

The [standalone move tests](../Tests/WarningResolution/test_event_move_indexes.py)
compile both production editor actions. The original passed ordinary moves
and endpoints, and failed 14 subcases involving invalid rows, missing
items, or wide positions. All three focused tests, all 66 Python standalone
tests, and the numeric alias check passed after the change. Artifacts are
in `/tmp/atlantis-increment3-event-moves.qsBFPM`.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed six warning sites. Atlantis warning lines fell
from 859 to 847, and the raw count fell from 1,620 to 1,608. There were no
new source diagnostics. The hosted test target built for both architectures.
All 66 selected hosted smoke tests passed on Intel with a disposable
profile. The capture, test log, and result bundle are in `smoke-current-user`.

## Third increment, Event Editor Conditions tab indexes

The baseline is Event Editor move batch commit `909740a`. The original
code narrowed the missing-tab sentinel, preventing the Conditions tab
from returning after an event type that does not support conditions.
The three tab lookups now preserve `NSInteger`. Row selection also
updates the tab view style when removing or restoring the tab.

The [standalone tab test](../Tests/WarningResolution/test_event_tab_indexes.py)
failed on the baseline and passed after the fix. All 67 standalone
tests and the numeric alias check passed. The hosted regression reproduced
the failure on both event-type and row changes on the baseline.
The build log and test artifacts are in
`/tmp/atlantis-increment3-event-tabs.0aGwir`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed three warning sites. Atlantis warning lines fell
from 847 to 841 and the raw count fell from 1,608 to 1,602. No new source
diagnostics appeared. The hosted test target built for both architectures.
All 67 selected hosted smoke tests passed on Intel after the fix. The
runs are in `smoke-before` and `smoke-after`.

## Third increment, Event Editor table hit indexes

The baseline is Conditions tab batch commit `968d412`. Both table hit
actions now validate the full-width AppKit row and column before
looking up the column or event. Previously a missing column reached
the array as an unsigned out-of-bounds index and raised a range
exception. A wide index could also alias an ordinary cell.

The [standalone hit tests](../Tests/WarningResolution/test_event_hit_indexes.py)
compile the production actions with synthetic hit results. Valid clicks
preserved name editing, extra-field editing, and the enable toggle.
All 16 invalid-hit subcases failed on the baseline and passed after the
guard. All 69 standalone tests and the numeric alias check passed.
Artifacts are in `/tmp/atlantis-increment3-event-hits.01fmht`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed four warning sites. Atlantis warning lines fell
from 841 to 833 and the raw count fell from 1,602 to 1,594. There were
no new source diagnostics. The hosted test target built for both architectures.
All 67 selected hosted smoke tests passed on Intel. The capture, test log,
and result bundle are in `smoke-current-user`.

## Third increment, Event Editor whole-event move indexes

The baseline is Event Editor hit-testing commit `06df675`. Both
whole-event move actions check the selected AppKit row and the signed
destination before converting them for the collection. The original
could truncate a wide row to an ordinary row and reorder the wrong
event. The responder reset, table reload, and selection of the moved
event are preserved.

The [standalone reorder tests](../Tests/WarningResolution/test_event_reorder_indexes.py)
compile the production move actions. The baseline passed ordinary
moves, endpoints, and an absent event within the collection bounds.
Six invalid selection subcases failed. After the fix all three focused
tests, all 72 standalone tests, and the numeric alias check passed.
Artifacts are in `/tmp/atlantis-increment3-event-reorder.V3jNEY`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed two warning sites. Atlantis warning lines fell
from 833 to 829 and the raw count fell from 1,594 to 1,590. There were
no new source diagnostics. The hosted test target built for both architectures.
All 68 selected hosted smoke tests passed on Intel, including the new
reorder check. The capture, test log, and result bundle are in
`smoke-current-user`.

## Third increment, Event Editor chain removal indexes

The baseline is whole-event reorder batch commit `a3cc2b1`. The
condition and action removal paths check their selected row before
looking up the event. They recognize Lemuria's `UINT_MAX` sentinel and
validate the position against the model array before lookup. Removing
an action now invalidates the action chain. The original invalidated
the condition chain. Lemuria's position lookup and related relayout
issue are tracked in `DiscoveredBugs.md` in the Lemuria checkout.

The [standalone chain removal tests](../Tests/WarningResolution/test_event_chain_removal_indexes.py)
compile both production actions. The baseline failed nine subcases
covering row validation, ranges, and redraw of the action chain.
All three focused tests, all 75 standalone tests, and the numeric
alias check passed after the fix. Artifacts are in
`/tmp/atlantis-increment3-event-chain-removal.vIj4Xl`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed two warning sites. Atlantis warning lines fell
from 829 to 825 and the raw count fell from 1,590 to 1,586. No new source
diagnostics appeared. The hosted test target built for both architectures.
All 68 selected hosted smoke tests passed on Intel. The capture, test log,
and result bundle are in `smoke-current-user`.

## Third increment, Event Editor selected rows

The baseline is chain removal batch commit `ae0c0fb`. Refresh, condition
mode changes, additions, and event removal now validate the full-width
selected row before collection lookup. The condition mode callback
accepts the Any and All menu entries. A missing or invalid menu index
preserves the current setting. The separate object initialization
issue is recorded in [Discovered bugs](DiscoveredBugs.md).

The [standalone selected-row tests](../Tests/WarningResolution/test_event_selected_rows.py)
compile five production methods. The original passed ordinary operations
and failed 14 subcases involving row or menu validation. All three focused
tests, all 78 standalone tests, and the numeric alias check passed after
the changes. Artifacts are in `/tmp/atlantis-increment3-event-selected.5Gdy0T`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed five warning sites. Atlantis warning lines fell
from 825 to 815 and the raw count fell from 1,586 to 1,576. No new source
diagnostics appeared. The hosted tests built for both architectures and
all 68 selected tests passed on Intel. Results are in `smoke-current-user`.

## Third increment, Event Editor extra-data column indexes

The baseline is selected-row batch commit `7a7d79f`. The positioned
extra-data column method now preserves AppKit's full-width lookup and
bounds-checks both indexes before moving. The original treated AppKit's
`-1` missing-column result as a valid index.

The [standalone column tests](../Tests/WarningResolution/test_event_column_indexes.py)
compile the production method. The baseline passed normal positioning
and failed five subcases covering a wide source, a missing column, and
out-of-range positions. Both focused tests, all 80 standalone tests,
and the numeric alias check passed after the fix. Artifacts are in
`/tmp/atlantis-increment3-event-columns.GRIgLa`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed one warning site. Atlantis warning lines fell
from 815 to 813 and the raw count fell from 1,576 to 1,574. No new source
diagnostics appeared. The hosted test target built for both architectures
and all 68 selected tests passed on Intel. Results are in
`smoke-current-user`.

## Third increment, EventCollection counts and indexes

The baseline is extra-data column batch commit `d0c3e80`. The collection
returns an `NSInteger` count and uses `NSUInteger` for lookup and moves,
matching the two framework boundaries. The editor preserves the
`NSNotFound` sentinel and checks the destination against the collection
count before selecting a signed AppKit row.

The [standalone collection test](../Tests/WarningResolution/test_event_collection_indexes.py)
compiles the production collection and editor methods together. It failed
on the baseline and passed after the fix, verifying ordinary selection,
absent events, and wide counts, selections, lookups, and moves. The editor
fixtures use the widened method signatures. All 81 standalone tests and
the numeric alias check passed. Artifacts are in
`/tmp/atlantis-increment3-event-collection.Y7UlyN`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed three warning sites. Atlantis warning lines fell
from 813 to 807 and the raw count fell from 1,574 to 1,568. No new source
diagnostics appeared. The hosted tests built for both architectures. All
68 selected tests passed on Intel, including the absent-event selection
check and ordinary reordering. Results are in `smoke-current-user`.

## Third increment, BaseEvent move source indexes

The baseline is EventCollection batch commit `e4e4610`. Both BaseEvent
move methods keep the array's full-width source index and check the
missing sentinel before the exchange. Destinations retain the signed
move API. The Event Editor still guards both positions before updating
the model and the Lemuria view.

The [standalone move tests](../Tests/WarningResolution/test_base_event_move_indexes.py)
compile both production methods. Two wide-source subcases failed on
the original and passed after the fix. Ordinary moves, missing items,
invalid destinations, and unchanged positions passed. All 83 standalone
tests and the numeric alias check passed. Artifacts are in
`/tmp/atlantis-increment3-base-event.mdhEEp`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed two warning sites. Atlantis warning lines fell
from 807 to 803 and the raw count fell from 1,568 to 1,564. No new source
diagnostics appeared. The hosted test target built for both architectures.
All 68 selected hosted smoke tests passed on Intel. Results are in
`smoke-current-user`.

## Third increment, collected-conditions indexes

The baseline is BaseEvent move batch commit `9676ce1`. A missing or
out-of-range menu selection now preserves the existing Any or All
mode. The removal action recognizes Lemuria's missing-position
sentinel and checks the array bound before removing a subcondition.
The additional caller is recorded in Lemuria's `DiscoveredBugs.md`.

The [standalone collected-condition tests](../Tests/WarningResolution/test_collected_condition_indexes.py)
compile both production actions. The original passed ordinary choices
and removals and failed six subcases involving invalid modes or missing
and out-of-range positions. The three focused tests passed after the
fix. All 86 standalone tests and the numeric alias check passed.
Artifacts are in `/tmp/atlantis-increment3-collected-condition.3QgFgB`.

A fresh arm64 and x86_64 Debug build with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed one warning site. Atlantis warning lines fell
from 803 to 801 and the raw count fell from 1,564 to 1,562. No new source
diagnostics appeared. The hosted test target built for both architectures.
All 68 selected hosted smoke tests passed on Intel. Results are in
`smoke-current-user`.

## Third increment, Computer Idle reader and units

The baseline is collected-conditions batch commit `1856fb5`. The old
condition turned 600 actual seconds into 558 and could abort on a short
data payload. The separate helper skipped acquisition after a successful
IOKit match. The baseline probes are in
`/tmp/atlantis-computer-idle-review.hs5XtN`.

The condition now uses one reader, releases owned IOKit and Core Foundation
objects, and distinguishes a valid zero reading from failure. The archive
still stores seconds. Threshold comparisons use exact nanosecond-to-second
units and preserve fractional thresholds.

The [standalone idle tests](../Tests/WarningResolution/test_computer_idle_reader.py)
compile the actual reader and condition comparison with stubbed IOKit.
They cover acquisition and read failures, resource release, both data
representations, invalid lengths and numeric values, and readings one
nanosecond below and at whole and fractional thresholds. The four tests
passed. After-change artifacts are in
`/tmp/atlantis-increment3-computer-idle.gAtP2Z`. All 90 standalone tests
and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed two narrowing sites and two deprecated
IOKit calls. Atlantis warning lines fell from 801 to 793 and the total
fell from 1,562 to 1,554. No new source diagnostics appeared. The hosted
test target built for both architectures and all 68 selected smoke tests
passed on Intel. Results are in `smoke-current-user`.

## Third increment, condition pattern menus

The baseline is Computer Idle batch commit `0919fb7`. The String Match
and Variable Match condition editors now check the full-width AppKit
menu index before replacing a pattern. A missing or out-of-range
selection preserves the existing pattern.

The [standalone pattern tests](../Tests/WarningResolution/test_condition_pattern_indexes.py)
compile both production callbacks. The original passed the four valid
choices and failed eight invalid-selection subcases. Both focused
tests passed after the change. Artifacts are in
`/tmp/atlantis-increment3-condition-patterns.I5lKJG`. All 92 standalone
tests and the numeric alias check passed.

The fresh arm64 and x86_64 Debug build used Xcode 26.6 (17F113) and the
macOS 26.5 SDK. It removed two warning sites. Atlantis warning lines fell
from 793 to 789 and the total fell from 1,554 to 1,550. No new source
diagnostics appeared. The hosted test target built for both architectures
and all 68 selected smoke tests passed on Intel. Results are in
`smoke-current-user`.

## Third increment, log export progress count

The log export progress count in `Log System/RDLogOpener.m` used a
32-bit unsigned local and a signed decimal label. The focused
`Tests/WarningResolution/test_log_export_count.py` probe failed on
`a671957` and passed after widening the count and using an unsigned
format. The probe covers both the label and progress maximum at zero,
42, 2³¹, and 2³² + 1.

The capture in `/tmp/atlantis-log-export.yMNDRA` has the fresh build,
warning comparison, and standalone logs. Xcode 26.6 (17F113) with
the macOS 26.5 SDK compiled arm64 and x86_64. The build removed one
Atlantis warning site on both architectures and added no source
diagnostics. The 1,538 lines comprise 777 Atlantis lines, 698 Lemuria
lines, 6 diagnostic echoes, 5 pathless warnings, and 52 sandbox-related
Xcode environment warnings. All 97 standalone checks and the numeric
alias check passed. All 68 hosted smoke tests passed on Intel in
`smoke-current-user`.

## Third increment, formatted-log wrapping

The `RDFormattedText` writer now measures margins in UTF-16 units and
wraps at composed-character boundaries. It preserves source characters
at hard wraps, omits the hyphen when needed to fit a whole grapheme,
and writes the remainder unwrapped when the prefix leaves no width.

The focused probe in `Tests/WarningResolution/test_formatted_log_wrap.py`
uses the production writer with an in-memory capture sink. Nine of its
eleven byte-for-byte cases failed on `fe59a1c`, and all eleven pass
after the fix. The capture is in `/tmp/atlantis-formatted-wrap.Zqmdyu`.
The universal Debug build with Xcode 26.6 (17F113) and the macOS 26.5
SDK removed the narrowing warning for arm64 and x86_64. The
comparison records 775 Atlantis warning lines and 1,536 total,
including 52 environment warnings, with no new source diagnostics.
All 98 standalone tests and the numeric alias check passed. All 68
hosted smoke tests passed on Intel in `smoke-current-user`.

## Third increment, log settings dialog responses

The formatted and HTML log settings dialogs narrowed AppKit modal
responses before checking for their own accept code 1. The focused
`Tests/WarningResolution/test_log_configuration_responses.py` probe
confirmed that both positive and negative wide responses with low
bits equal to 1 applied new settings. Both dialogs now compare the
full AppKit response. The probe fails on `6f2c8bd` and passes after
the fix.

The fresh universal Debug build removed two warning sites on both
arm64 and x86_64 with no new source diagnostics. It has 771 Atlantis
warning lines and 1,532 total, including 52 Xcode environment
warnings. All 99 standalone tests and the numeric alias check passed.
All 68 hosted smoke tests passed on Intel in `smoke-current-user`.

The fresh capture and the separate overwrite-alert probe are in
`/tmp/atlantis-log-modal.dnvcYz`. The overwrite and append paths need
review before batch 33. See the
[workplan](WarningResolutionWorkplan.md#third-increment-batches).

## Third increment, log save-panel replacement and append

The legacy alert narrowed its response, and its filename-validation
callback deleted or moved existing data before the logger was ready.
The save panel now waits for the confirmed URL, then uses an explicit
full-width response. Create and Replace prepare a sibling file and
publish it atomically. Append uses an identity-checked descriptor
opened in append mode. Cooperative locks protect active Atlantis logs.
See the [workplan](WarningResolutionWorkplan.md#third-increment-batches)
for the transaction and the original reproduction.

The capture is in `/tmp/atlantis-log-replace.yu2imC`. The focused
overwrite response check is
`Tests/WarningResolution/test_log_overwrite_response.py`. The hosted
tests in `Tests/AtlantisTests/ANSIColorTests.swift` exercise the
production logger against disposable files and compare their exact
bytes through preparation, failed and successful publication, and
append.

The fresh capture in `verified-build.log` used Xcode 26.6 (17F113)
and the macOS 26.5 SDK to build arm64 and x86_64. The comparison
removed 12 warning sites across both architectures and added no
source diagnostics. The capture has 747 Atlantis warning lines and
1,508 total, including 52 environment warnings. All 100 standalone
tests and the numeric alias check passed. In `smoke-final`, all 75
hosted tests passed on Intel. The earlier `smoke-current-user` run
passed the log tests and failed
`RDAtlantisSpawnTests.testCommittedInputAddsPrefixOnce`, which passed
on rerun.

## Post-profile warning baseline

Commit `9910494` adds optional Atlantis profile storage. Its fresh
universal Debug build succeeded with Xcode 26.6 (17F113) and the macOS
26.5 SDK. The raw warning counts match `ee9deed`: 2,182 total, 1,421
Atlantis-path, and 698 Lemuria-path. The source comparison flagged ten
edited lines whose existing diagnostics moved with them. Review of the
locations and messages found no new warning sites.

Artifacts are in `/tmp/atlantis-profile-warning-baseline.RpwQGe`, including
the build log, numbered warnings, source comparison, and a passing
synthetic fixture capture for the new build.

Run the automated application smoke suite from the current macOS user.
The [workplan](WarningResolutionWorkplan.md#automated-application-smoke-tests)
has the build and run commands. The runner uses the hosted Atlantis app
with a disposable bundle identifier and profile. The smoke gate covers
Atlantis functionality and excludes macOS settings and saved window
frames.

The current-user application baseline built the app at `9910494` and
passed all 57 selected hosted tests. The loopback world rendered the
split Truecolor prompt, sent the expected ASCII and UTF-8 bytes with
CRLF, and disconnected and reconnected. The runtime capture confirmed
the disposable storage path and preference suite.

Artifacts are in `/tmp/atlantis-application-smoke.4IpMgE/results`:

- `capture.json` records the revision, profile, toolchain, test selection,
  and result counts.
- `Smoke.xcresult` contains the hosted XCTest results.
- `test.log` includes startup and test execution details.

If the temporary artifacts are gone, use the workplan's smoke commands
to recreate them before beginning the first warning batch.

## Third increment, world editor Keepalive selection

The Keepalive change handler and final commit now share validation of
the native AppKit index. Both preserve an existing preference when no
valid row is selected. Restoration displays row 0 for invalid or
missing values. The focused probe at
`Tests/WarningResolution/test_world_keepalive_selection.py` failed on
`1969b9a` and passed after the fix. The capture is in
`/tmp/atlantis-keepalive-verified.RTIqtP`.

Xcode 26.6 (17F113) and the macOS 26.5 SDK built both architectures.
The fresh build removed both warning sites on arm64 and x86_64, with
743 Atlantis warning lines and 1,504 total. No source diagnostics
were added. All 101 standalone tests and the numeric alias check
passed. All 76 hosted smoke tests passed on Intel in
`smoke-current-user`, including the pending spawn input diagnostic
test in the working tree.

## Third increment, world editor Server Type selection

Both Server Type save paths now reject invalid native-width indexes
and preserve the stored world preference. The change handler sets
the MUD scrollback default only for a valid MUD selection without an
existing value. Restoration displays the existing row-0 default for
invalid or missing preferences. The focused probe at
`Tests/WarningResolution/test_world_server_type_selection.py` failed
on `cc48db6` and passed after the fix. The capture is in
`/tmp/atlantis-server-type-verified.dBCXN8`.

Xcode 26.6 (17F113) and the macOS 26.5 SDK built arm64 and
x86_64. The fresh comparison removed both warning sites on both
architectures with no new source diagnostics. It has 739 Atlantis
warning lines and 1,500 total. All 102 standalone tests and the
numeric alias check passed. All 76 hosted smoke tests passed on Intel
in `smoke-current-user`, including the pending spawn input diagnostic
test in the working tree.

## Third increment, world editor startup selection

The source baseline is `cdd43e7`. Both startup control actions and
the final save use native-width AppKit values. Invalid menu selections
preserve the mode, and a wide checkbox state can no longer alias On.
The focused probe at
`Tests/WarningResolution/test_world_autoconnect_selection.py` exercises
72 cases. Twenty-nine failed on the baseline and all passed after
the fix. See the [workplan](WarningResolutionWorkplan.md#third-increment-batches)
for the command and preference mapping.

Xcode 26.6 (17F113) and the macOS 26.5 SDK built arm64 and x86_64.
The baseline app build has 1,446 raw warning lines, including 739
Atlantis lines. The revised hosted build has 1,465 raw warning
lines, including 727 Atlantis app lines and 30 test-target lines.
All six narrowing sites disappeared on both architectures. No new
Atlantis app source diagnostics appeared. Lemuria stayed at 698.
The logs and comparison are in `/tmp/atlantis-autoconnect.Hf1alI`.
All 103 standalone tests, the numeric alias check, and all 76
hosted smoke tests passed. Hosted execution used Intel and included
the pending spawn input diagnostics.

## Third increment, world editor SSL selection

At `3ec19ea`, final save narrowed the checkbox state to `int`.
The focused `Tests/WarningResolution/test_world_ssl_selection.py`
probe confirmed that a synthetic wide checkbox state enabled SSL
only through final save. Final save now shares the interactive
action for an enabled control and clears the override if disabled.
The same probe passed after the fix.

Universal Debug `build-for-testing` with Xcode 26.6 (17F113) and the
macOS 26.5 SDK removed the warning on both arm64 and x86_64. It
captured 755 Atlantis warning lines (725 in the app) and 1,463
total, with no new source diagnostics. All 104 standalone tests,
the numeric alias check, and all 76 Intel hosted smoke tests
passed. Logs and artifacts are in `/tmp/atlantis-ssl.5XkAYL`.

## Third increment, connected-world quit confirmation

At `e3b5fa6`, the termination delegate narrowed AppKit's response and
proceeded with quitting on unexpected responses. The focused
`Tests/WarningResolution/test_quit_confirmation.py` probe failed for
an abort, an alert error, and a wide response. All twelve cases pass
with the full-width result and exact legacy Quit response check.

Xcode 26.6 (17F113) and macOS SDK 26.5 built arm64 and x86_64. The
narrowing warning disappeared on both architectures. The existing
deprecation now names the legacy default response constant. The
hosted build captured 753 Atlantis warning lines (723 app lines)
and 1,461 total. All 105 standalone tests, the numeric alias check,
and all 76 Intel hosted smoke tests passed. Artifacts are in
`/tmp/atlantis-quit.YI9r3t`.

## Third increment, startup version handling

At `8d2b650`, startup narrowed the stored version to `int`. The
focused test in `Tests/WarningResolution/test_startup_version.py`
uses disposable defaults and intercepts the reset. A synthetic
nonzero version of `4294967296` triggered the reset before the fix.
With the native-width value, all ten cases pass. Explicit zero and
missing versions still request a reset in standard defaults, and
named profiles still skip it. See the
[follow-up](DiscoveredBugs.md#investigate-the-zero-version-startup-preferences-reset)
for questions about old preference formats and prompting.

The fresh Xcode 26.6 (17F113) Debug build with the macOS 26.5 SDK
removed the warning on arm64 and x86_64, with no new source
diagnostics. It captured 751 Atlantis warning lines (721 app lines)
and 1,459 total. All 106 standalone tests, the numeric alias check,
and 76 Intel hosted smoke tests passed. Logs and test artifacts are
in `/tmp/atlantis-startup-version.kw1mMl`.

## Third increment, event class registry counts

At `1305f4e`, both registry count selectors returned a 32-bit value
from the backing array. The focused
`Tests/WarningResolution/test_registry_counts.py` probe compiles the
production methods against their headers. Both baseline methods
truncated a wide count to 1. The revised methods preserve zero,
ordinary counts, and the wide count at the declared native width.

The universal Xcode 26.6 (17F113) Debug build removed both warnings
on arm64 and x86_64. It captured 1,455 warning lines, including 747
Atlantis lines (717 in the app) after rejoining one split diagnostic.
All 107 standalone tests, the numeric alias check, and 76 Intel hosted
smoke tests passed. Artifacts are in `/tmp/atlantis-registry-counts.GYQR80`.

## Third increment, view-weight path splitting

At `b3ed18e`, the spawn substring start was narrowed to `int`.
The focused `Tests/WarningResolution/test_view_weight_range.py` probe
failed on a synthetic wide split. The revised method uses `NSUInteger`
for the range and passes every case, including the existing weight zero
when a live world or spawn configuration is missing. The saved
preference fallback is recorded for separate investigation.

The universal Xcode 26.6 (17F113) Debug build removed the warning on
arm64 and x86_64. It captured 745 Atlantis warning lines (715 app
lines) and 1,453 total, with no new source diagnostics after rejoining
the split baseline diagnostic. All 108 standalone tests, the numeric
alias check, and all 76 Intel hosted smoke tests passed. Artifacts
are in `/tmp/atlantis-view-weight.dz9xC1`.

## Third increment, Dock badge count

At `8b64b19`, narrowing the active-view count hid the badge for
synthetic counts of 2³¹ and 2³² and displayed 1 for 2³² + 1. The
focused `Tests/WarningResolution/test_dock_badge_count.py` probe
now passes for exact decimal labels, zero, and the existing
visibility settings with native-width unsigned counts.

The universal Xcode 26.6 (17F113) Debug build removed the warning on
arm64 and x86_64. It captured 743 Atlantis warning lines (713 app
lines) and 1,451 total. No new source diagnostics appeared. All 109
standalone tests, the numeric alias check, and 76 Intel hosted smoke
tests passed. Artifacts are in `/tmp/atlantis-dock-badge.oci0RQ`.

## Third increment, text template expansion

The four range sites at `c340f8a` narrowed UTF-16 offsets in
`expandWithDataIn:`. The standalone probe exercises the production
method with a synthetic wide template, temporary variable lookups,
negative limits, and grapheme-aware truncation. The
[workplan](WarningResolutionWorkplan.md#third-increment-batches) and
[scripting guide](JavaScriptScripting.md#template-expansion-length-limits)
record the resulting behavior. The Dock label cap was committed
separately at `1fe2018`.

Xcode 26.6 (17F113) and the macOS 26.5 SDK built both arm64 and x86_64.
The build removed eight architecture-specific warning lines, leaving
735 Atlantis lines (705 app lines) and 1,443 total. No new source
diagnostics appeared after accounting for shifted lines. All 110
standalone tests, the numeric alias check, and all 76 Intel hosted
smoke tests passed. Artifacts are in `/tmp/atlantis-expansion-batch.TlnNOo`.

## Third increment, string line counting

At `a65b35e`, a wide NSString length narrowed in the line-count loop
and could skip the scan altogether. The focused
`Tests/WarningResolution/test_string_line_count.py` probe verifies
the native-width result and synthetic iteration while preserving
line counts for empty, ordinary, CRLF, and multibyte text.

Xcode 26.6 (17F113) and the macOS 26.5 SDK built arm64 and x86_64.
The universal Debug build removed one narrowing site on both
architectures with no new source diagnostics. It captured 733 Atlantis
warning lines (703 app lines) and 1,441 total. All 111 standalone
tests, the numeric alias check, and all 76 Intel hosted smoke tests
passed. Artifacts are in `/tmp/atlantis-line-count-batch.lyeOiP`.

## Third increment, World Formatting codepage saves

At `324c476`, three save paths narrowed an AppKit item tag to 32 bits.
The original and revised code passed the same focused preference probe,
including UTF-16BE, explicit autodetect, missing selection, and
inherited defaults. The save conversion remains unsigned 32-bit and
the [restore defect and streaming decoder investigation](DiscoveredBugs.md#restore-saved-codepages-with-high-bit-ids)
are deferred.

The Xcode 26.6 (17F113) Debug build removed all three sites on arm64
and x86_64 with no new source diagnostics. It captured 727 Atlantis
warning lines (697 app lines) and 1,435 total. All 112 standalone
tests, the numeric alias check, and 76 Intel hosted smoke tests
passed. Artifacts are in `/tmp/atlantis-codepage-batch.0dhuTk`.

## Third increment, World Formatting linefeed saves

At `9d8209b`, the popup action and inherited-defaults toggle narrowed
their AppKit row indexes before persisting them. The focused
`Tests/WarningResolution/test_linefeed_saves.py` probe failed on the
baseline and passes with the full-width row validation. Both paths
preserve the prior preference for an invalid selection and remove the
override when using inherited defaults. Valid rows still store 0 for
LF and 1 for CRLF.

The Xcode 26.6 (17F113) Debug build with the macOS 26.5 SDK removed
both sites on arm64 and x86_64 with no new source diagnostics. It
captured 723 Atlantis warning lines (693 app, 30 test target), 698
Lemuria lines, and 1,431 total. All 113 standalone tests and the
numeric alias check passed.
All 76 hosted smoke tests passed on Intel, including the pending spawn
input diagnostics. Artifacts are in `/tmp/atlantis-linefeed-batch.BzRPjJ`.

## Third increment, MUSH Text Editor format tags

At `baf24e6`, format restoration, saves, and export narrowed the native
AppKit or defaults tag to `int`. The focused probe in
`Tests/WarningResolution/test_mush_format_tags.py` reproduced the wide
tag alias and passed after all three paths adopted `NSInteger`.
The four configured formats still produce the same export bytes.
The [ANSI function export and palette lookup issues](DiscoveredBugs.md#preserve-color-across-mush-ansi-function-export-runs)
have a separate reproduction and are deferred.

The Xcode 26.6 (17F113) Debug build with the macOS 26.5 SDK removed
all three sites on arm64 and x86_64 with no new source diagnostics.
It captured 717 Atlantis warning lines (687 app, 30 test target),
698 Lemuria lines, and 1,425 total. All 114 standalone tests, the
numeric alias check, and 76 Intel hosted smoke tests passed. Artifacts
are in `/tmp/atlantis-mush-tags.z4j1Fp`.
