# Preference pane migration workplan

All six pane migrations are complete. General, Networking, and Windowing use
SwiftUI forms. World Defaults, Hotkeys, and Toolbar Events use Swift adapters
around the existing AppKit editors. See the execution record below for the
verification results.

Migrate one pane at a time. Preserve the AtlantisPreferencePane protocol,
Objective-C runtime names and initializer selectors, registration, defaults
keys, and archive formats. Keep the native preferences window and toolbar.

For each pane, characterize the current Objective-C behavior in hosted XCTest.
Then run those checks against Swift, verify the hosted layout, update the
Xcode source and resource memberships, and record the former outlet, action,
and delegate seams. Use isolated defaults and temporary archives where
possible. Retain the original initial view size and run the shared window suite
after each change.

| Order | Pane | Implementation and regression coverage |
| --- | --- | --- |
| 1 | General | Replace the XIB with a SwiftUI form. Cover saved values, inverted switches, beep choices, URL length editing and enablement, and live shortcut and badge updates. |
| 2 | Networking | Replace the XIB with a SwiftUI form. Cover proxy modes, disabled fields, retained values, port conversion, focus order, and editing-end persistence. |
| 3 | Windowing | Replace the XIB with SwiftUI controls. Cover native grouping and navigator mappings, drag inversion, small icons, spawn status placement, and notification delivery. |
| 4 | World Defaults | Port the pane to Swift and host the existing world editor. Cover global-tab filtering and order, outgoing-tab commits, batched commits, and font forwarding. |
| 5 | Hotkeys | Port the pane and delegates to Swift and host the existing event editor and sheets. Cover key capture, collection mutation, selection, action insertion, and archive compatibility. |
| 6 | Toolbar Events | Port the pane and delegates to Swift and host the existing event editor and action picker. Cover event defaults, selection, picker callbacks, and archive compatibility. |

Shared world and event editor replacements are separate follow-up work.

## Execution record

Each characterization run used the Objective-C implementation of the pane
under test. Each migrated run included the existing hosted window and spawn
regression tests.

| Pane | Characterization suite | Migrated suite |
| --- | ---: | ---: |
| General | 13 passed | 15 passed |
| Networking | 16 passed | 18 passed |
| Windowing | 19 passed | 21 passed |
| World Defaults | 22 passed | 23 passed |
| Hotkeys | 24 passed | 25 passed |
| Toolbar Events | 26 passed | 27 passed |

The final build includes Intel and Apple silicon. Hosted tests ran on Intel.
The smoke test checks layout and attachment programmatically. Manual visual
review and end-to-end keyboard traversal were outside that verification.
