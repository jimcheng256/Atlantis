# Atlantis profile directories

Launch the executable directly to opt in to a separate Atlantis profile.

```sh
/path/to/Atlantis.app/Contents/MacOS/Atlantis --profile-directory /path/to/profile
```

Startup creates the profile and its `worlds` and `Logs` directories and reports
the effective storage directory and preference suite on the process log.
The suite name derives from the canonical path. Reopening that path reuses
the suite. macOS stores suite preferences separately from the profile's
archive files. Moving the directory changes the suite identity.

Atlantis-owned preferences, worlds, hotkeys, toolbar events, globals,
and the default log directory use the selected profile. Explicit file
paths still resolve normally. Omitting the flag preserves the normal
Atlantis defaults and Application Support directory.

Lemuria and AppKit continue using the application preference domain for
framework settings such as window grouping and view state. The Preferences window disables frame
autosave in profile mode. Sparkle's automatic update cycle is skipped in
profile mode. Use a disposable GUI account when validating that a smoke
session leaves the normal application's window and framework state intact.
