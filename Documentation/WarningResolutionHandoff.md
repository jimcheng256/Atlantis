# Atlantis warning resolution handoff

## Current state

- Branch `warning-resolution` starts from `main` at `ee9deed`
  (`feat(telnet): prefer UTF-8 in CHARSET`).
- The [warning resolution workplan](WarningResolutionWorkplan.md) is written
  and awaiting approval to execute. The fresh warning capture and triage
  are complete. The first fix batch, characterization tests, and application
  smoke baseline are pending.
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

1. Run and record the workplan's smoke checklist against the baseline
   before editing. Use a disposable world, a local Telnet fixture, and
   temporary preferences, archives, and logs.
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
   and the full smoke checklist. Present the results for review before
   moving on to deprecated constants and mechanical cleanup.
