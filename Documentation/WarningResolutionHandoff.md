# Atlantis warning resolution handoff

## Current state

- Branch `warning-resolution` starts from `main` at `ee9deed`
  (`feat(telnet): prefer UTF-8 in CHARSET`).
- The [warning resolution workplan](WarningResolutionWorkplan.md) has a
  fresh warning capture and an automated application smoke baseline.
  The first fix batch and its focused characterization tests are pending.
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

## First batch after approval

1. Use the captured automated smoke baseline below for comparison. Run
   the focused characterization checks before editing the first batch.
2. Inventory the Atlantis format and expression diagnostics, which account
   for 20 baseline lines including repeats. Inspect the ineffective length
   guard in `Utility Classes/HIDIdleTime.m`, the format call in
   `Utility Classes/RDStringPattern.m`, and the BOOL comparison in
   `Event System/Actions/Action-OpenLog.m`. Verify each intended behavior
   independently before applying a fix.
3. Run focused characterization tests against the original code. Run the
   same assertions after each substantive change and document any agreed
   correction separately. Pay particular attention to literal percent
   signs, valid and invalid lengths, and observable UI or logging behavior.
4. Finish the batch with a fresh warning comparison, relevant hosted tests,
   and the automated smoke suite. Present the results for review before
   moving on to deprecated constants and mechanical cleanup.

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
