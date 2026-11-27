# Atlantis warning resolution handoff

## Current state

- Branch `warning-resolution` starts from `main` at `ee9deed`
  (`feat(telnet): prefer UTF-8 in CHARSET`).
- The [warning resolution workplan](WarningResolutionWorkplan.md) has a
  fresh warning capture and an automated application smoke baseline.
  The first increment is committed at `b5836e8`. The second increment
  is committed at `f576972`. The picker batch is committed at
  `49330c1`, the editor batch at `76b2a75`, and the log-closing table batch
  at `cc5291e`. The latest integer-narrowing batch covers the User
  Variables table in World Configuration.
- Review the User Variables batch before selecting the next AppKit UI
  path. Keep byte-level conversions in separate batches.
- The generated change in `English.lproj/InfoPlist.strings` predates this
  effort. Preserve it and stage only explicit task files.
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
