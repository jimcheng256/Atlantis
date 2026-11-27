# Working in Atlantis

Atlantis is a macOS application with Objective-C, AppKit, Swift, and SwiftUI
code. Build it with the shared `Atlantis` scheme in `Atlantis.xcodeproj`.
The app and hosted tests target macOS 13.5. The project references Lemuria
at `../Lemuria/Lemuria.xcodeproj`. See [README.md](README.md) for checkout
setup.

## Making changes

- Check the working tree before editing. Preserve unrelated changes,
  including generated changes to `English.lproj/InfoPlist.strings`.
- Keep changes scoped to the feature. When porting Objective-C code, check
  the runtime class name, selectors, call sites, and ownership of shared
  AppKit views. Preserve these interfaces unless the task changes them.
- Update Xcode groups, build phases, and app or test target membership when
  adding, moving, or removing sources and UI resources. Check project-file
  edits with `plutil -lint Atlantis.xcodeproj/project.pbxproj`.
- Before removing apparently unused files, check Xcode build and copy phases,
  source and XIB references, runtime lookups, and packaging inputs. For UI
  resource cleanup, build with fresh derived data and inspect the resulting
  app bundle.
- Put hosted XCTest coverage in `Tests/AtlantisTests`. For behavior-preserving
  migrations, characterize the old behavior before replacing it. Exercise
  the actual hosted window or editor for layout, focus, and responder changes.
  Use temporary defaults suites and archive paths for persistence tests.
- Put standalone warning-resolution unit tests in `Tests/Focused`. Run
  them when verifying warning fixes or tracing regressions from that work.
  Routine verification for new Atlantis features uses the relevant app
  and hosted tests.
- For warning cleanup, verify Xcode fix-its against the API contract and the
  actual call sites. For substantive changes beyond renames and verified
  constant aliases, run the same focused assertions before and after the
  edit. Exercise numeric boundaries and compare exact bytes for changes to
  protocol fields, buffer lengths, or encoded output.
- Update the relevant architecture documentation when changing behavior,
  integration points, or test commands.
- Keep README.md focused on the project overview and checkout and build setup.
  Put implementation details, architecture notes, and feature-specific test
  instructions in the relevant files under `Documentation/`.

## Verification

Run the smallest relevant checks first, then the shared hosted suite when
changing window, pane, or editor behavior.

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Use full Xcode for hosted tests. If the environment separates building and
GUI test execution, use `build-for-testing` followed by
`test-without-building` with the same scheme, destination, build settings,
and derived data path. Report compile coverage and runtime coverage
separately when they differ.

Run application tests in the current macOS user context. Use hosted
XCTest, temporary profiles, and disposable fixtures for isolation.
Separate GUI logins cannot be automated in this workflow. Do not propose
switching accounts, creating a test user, or asking someone to sign into
another desktop. Focus smoke coverage on Atlantis functionality and
correctness. Omit macOS settings and saved window positioning.

For the warning-resolution effort, follow the
[warning workplan](Documentation/WarningResolutionWorkplan.md) one batch at
a time. Limit changes to Atlantis and keep Lemuria in the integration build.
Compare fresh build diagnostics between batches. Run
[`Tests/Smoke/run.py`](Tests/Smoke/run.py) on the Debug
`build-for-testing` products as described in the workplan. Keep the
smoke capture, test log, and XCTest result bundle outside the checkout.

## Git and pull requests

- Stage explicit task files and verify the staged diff. Treat a request for
  a commit message preview as a review step.
- Follow [the commit template](.gitcommit) using a concise
  `type(scope): subject`.
- Verify the remote owner and PR base before publishing, particularly in a
  fork. Use the destination the user requested. Opening a PR and merging
  it are separate actions.

## Repository references

- [Durable engineering learnings](Documentation/EngineeringLearnings.md)
- [Preferences architecture](Documentation/AtlantisPreferences.md) and
  [pane migration record](Documentation/PreferencePaneWorkplan.md)
- [Spawn architecture and editor integration](Documentation/RDAtlantisSpawn.md)
