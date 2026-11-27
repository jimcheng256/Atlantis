# Atlantis warning resolution handoff

## Current state

- Branch `warning-resolution` starts from `main` at `ee9deed`
  (`feat(telnet): prefer UTF-8 in CHARSET`).
- The [warning resolution workplan](WarningResolutionWorkplan.md) has a
  fresh warning capture and an automated application smoke baseline.
  The first increment is committed at `b5836e8`. The second increment
  covers deprecated numeric constants and mechanical cleanup and is ready
  for review before integer narrowing.
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
  -framework AppKit -framework Foundation Tests/Focused/warning_constant_aliases.m \
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
