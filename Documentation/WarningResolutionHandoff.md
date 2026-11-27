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
- The fifteenth batch covers Event Editor `moveUp:` and `moveDown:`.
  Its universal Debug capture is the next baseline, with 847 Atlantis
  warning lines and 1,608 total. Artifacts are in
  `/tmp/atlantis-increment3-event-moves.qsBFPM`.
  Review the Conditions tab restoration issue before the next batch.
  The workplan records the AppKit sentinel probe and proposed hosted check.
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
