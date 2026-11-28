# Discovered Atlantis bugs

## Event creation skips initialization and loses the World Idle default

The **World Idle** condition becomes true when a world is connected and
the time since its last network activity reaches the configured threshold.
The condition's description mentions what the user sends. In the current
implementation, `RDAtlantisWorldInstance` updates `lastNetActivity` on
outgoing data, nonempty incoming data, and connection establishment.
The intended default is 600 seconds (10 minutes). A zero-second threshold
effectively removes the waiting period. Other event conditions still apply.

`Condition_WorldIdle` assigns the 600-second default in `init`. The
Event Editor's Add Condition menu and the condition registry factory use
`class_createInstance`, which allocates and zeroes storage without calling
`init`. A probe using the production methods found 600 seconds after
direct initialization and zero seconds through both creation paths.
Calling `init` in the Event Editor probe restored 600 seconds there.
The registry still returned zero. Probe sources and logs were captured
in `/tmp/atlantis-event-creation-review.l4owJd`.

The Action and Condition pickers, class registries, and nested condition
editor also use runtime allocation. Audit their initialization and
ownership contracts together, including delegate handoff, then verify
the defaults of real subclasses through the affected entry points.
Check existing archives separately. A saved zero may represent a
deliberately configured threshold.

This lifecycle bug was found while tracing selected-row handling in
the warning-resolution effort. Integer narrowing affects which event
receives a condition. Initialization determines that condition's
starting state. The lifecycle fix is deferred to separate work.

## Review certificate trust for direct TLS connections

The [direct TLS setup](../Worlds/RDAtlantisWorldInstance.m) disables
certificate-chain validation and allows expired certificates and arbitrary
roots. Review server identity and certificate validation as separate work.
Decide how existing worlds with self-signed certificates should establish
trust, then verify trusted, untrusted, expired, and hostname-mismatched
certificates with disposable test endpoints.

## Investigate the zero-version startup preferences reset

[Startup migration](../Core/RDAtlantisMainController.m) uses a zero
`RDAtlantisVersion` in standard defaults as a trigger to reset defaults
and attempt to remove the standard Atlantis preferences plist. A missing
version reads as zero even with other preferences present. Named profiles
skip this reset. Batch 39 retains this behavior and prevents nonzero wide
versions from aliasing zero.

A PowerPC-era installation is one possible source of unversioned
preferences. The current code does not identify the source release.
A fresh install and an existing preferences domain with a missing version
can take the same path. Check historical releases and sample preference
files to determine when the version key appeared, what prompted the
original reset, and which formats can still be migrated. Distinguish an
empty domain from one with recoverable user settings. Check world and
character archives separately from application defaults.

Consider a prompt before resetting a populated domain once supported
migration paths are understood. Evaluate preserving or backing up the
settings before any reset, the choices to offer when migration is
unsupported, and how to avoid repeating the prompt at every launch.
Test with copied fixtures and disposable profiles.

## Investigate the unreachable saved view-weight fallback

In Atlantis's [view-weight delegate](../Core/RDAtlantisMainController.m),
paths without a colon use an empty string as the spawn path. Paths with a
colon use a substring. For ordinary paths with a world name, both cases
enter the live-instance lookup, so the saved world-preference fallback
requiring a nil spawn path is unreachable. When the lookup finds no live
world or matching spawn configuration, Atlantis returns weight zero.
Batch 41 preserves that ordering behavior.

Lemuria creates a placeholder when a child is added to a window without
its parent view, such as when a spawn is moved to another window. The
world may still have a live instance, in which case the existing
configuration supplies the weight. Before changing the fallback, confirm
when a root placeholder lacks a live instance, how character-specific
and world-level preferences should apply, and whether the ordering should
change when a real parent replaces the placeholder. Exercise those cases
with actual nested views and windows.

## Restore saved codepages with high-bit IDs

The [World Formatting editor](../Preferences/World/WorldFormattingEditor.m)
builds the codepage menu from Foundation's available string encodings.
It saves the selected ID as an unsigned 32-bit number, but restores the
menu through `intValue`. On 64-bit builds, IDs above `INT_MAX` become
negative tags that cannot match their positive menu tags. The popup
clears its selection. Committing without a new selection writes tag
zero, which means autodetect, over the saved codepage. A Foundation
probe found 88 affected encodings on the review machine, including
UTF-16BE, UTF-32, Shift JIS, and Big 5. A separate AppKit probe verified
the empty selection and subsequent zero value.

The signed read and unsigned save are both present in `d889c18`, the
October 2016 import from Subversion. That project targeted 32-bit i386
and PowerPC, where the signed menu tag could still retain the ID's bit
pattern. The popup mismatch likely dates to the February 2019 64-bit
conversion in `b417e5e`. This is an inference from the source and build
settings. The current probes are in `/tmp/atlantis-codepage-review.anFOBJ`.

Connection setup also reads the preference through `intValue` before
assigning it to `NSStringEncoding`. The probe confirmed sign extension
but did not establish a difference in encoded bytes. Review the menu
restore, absent and unknown selections, legacy saved numbers, and the
connection path together. Verify editor persistence and exact bytes
for representative encodings. The [inbound multibyte
filter](../Filter%20System/RDMultibyteFilter.m) only applies its byte
holdover to UTF-8. It scans trailing high-bit bytes without checking
codepoint boundaries, so it can also delay complete UTF-8 characters.
Single-byte encodings such as ASCII and ISO Latin-1 need no byte holdover
for character boundaries. Multibyte encodings need a decoder that keeps
incomplete sequences across reads. Stateful encodings such as ISO-2022-JP
also need to retain shift state. Verify exact decoded text at split
boundaries for representative encodings and check decoder state when the
encoding changes or the connection closes.

Batch 45 makes the save conversions explicit and preserves the existing
preference and restore behavior.

Discussion and investigation notes are in the
[Atlantis codepage conversation](https://chatgpt.com/g/g-p-6b07f61eb230819190a2b3846fb327ff-atlantis/c/6b0a86b4-ca10-83e8-9280-26dac4366fe0).

## Preserve color across MUSH ANSI function export runs

At `baf24e6`, the [MUSH Text Editor exporter](../Misc/MUSHTextEditor.m)
tracks foreground and background transitions across attributed runs.
The **Use ansi() for color** format wraps each run independently.
A second run with the same foreground can therefore lose its wrapper
even though its color still applies.

To reproduce in a host or a focused probe, configure an ANSI palette
with red at index 1, select format tag 2, and give the editor an
attributed string containing `AB`. Set `NSForegroundColorAttributeName`
to that same red on both characters. Add a custom attribute such as
`ProbeRunBoundary = YES` only to the second character to force a
distinct effective range without changing its appearance. Call
`editorAsMUSHText` and compare the exact UTF-8 output:

| Input | Output at `baf24e6` |
| --- | --- |
| Both red characters in a single attribute run | `[ansi(r,AB)]` |
| Both red characters in separate attribute runs | `[ansi(r,A)]B` |

Both characters should export as red. Either a shared wrapper or a
separate red wrapper for each run can represent that result. The
focused probe used the production exporter and color methods with
an in-memory attributed string. Its source and captured output are
in `/tmp/atlantis-mush-review.fdB7oK`.

The same review verified that `idForColor:` narrows `NSNotFound` to
`-1` while callers compare against the full-width sentinel. Review
missing palette colors alongside export state transitions. Cover
foreground, background, style changes, and exact output for both
persistent color-code formats and the `ansi()` format.

## Evaluate stacked-command send limits and partial execution

The [stacked-command parser](../Command%20System/StackedCommand.m)
sends each segment as soon as it encounters the next repeat count.
A probe of `9f4d272` with a recording world and signed-overflow
sanitization sent `look` before reporting overflow on
`1look2147483648score`. Batch 51 clamps the parsed count to
`INT_MAX` and preserves immediate per-segment sends.

Evaluate a practical limit per segment or per invocation, whether
to validate the whole input before sending, and how to report a
rejected count. A count at `INT_MAX` can still request that many
synchronous sends. Use a recording world and small test limits when
checking ordering, partial execution, and rejection.

Riverdark records `/sc` in its [0.8.5 version history](https://www.riverdark.net/atlantis/history.php).
The [community guide](https://gdb.armageddon.org/index.php/topic,53346.0.html)
illustrates the syntax with `/sc 1n3e`.

Include `/sc` in future end-user documentation work. Explain where
to enter it, how ASCII counts delimit command text, how zero counts
behave, and how digits inside command text start a new segment. Add a
worked example and document the execution limits and error behavior
in effect when the guide is written.

## Validate world archive roots before startup sorting

At `79af4f0`, [`WorldCollection.loadAllWorlds`](../Worlds/WorldCollection.m)
adds every non-nil object decoded from an `.awd` file to the world
collection. The sort comparator then asks each object for its world
name using `preferenceForKey:withCharacter:`. A valid keyed archive
can contain a root object of another type.

To reproduce, use a disposable profile directory and create two
keyed archives containing strings:

```sh
profile="$(mktemp -d /tmp/atlantis-world-archive.XXXXXX)"
mkdir "$profile/worlds"
cat > "$profile/make-fixtures.swift" <<'SWIFT'
import Foundation

let worlds = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for name in ["first", "second"] {
    let data = try NSKeyedArchiver.archivedData(withRootObject: name, requiringSecureCoding: false)
    try data.write(to: worlds.appendingPathComponent("\(name).awd"))
}
SWIFT
swift "$profile/make-fixtures.swift" "$profile/worlds"
```

Launch the Atlantis executable with `--profile-directory "$profile"`,
or initialize a `WorldCollection` with `"$profile/worlds"` and call
`loadAllWorlds` in a hosted test. The two entries force a comparison.
A focused probe using the production loader, sort method, and comparator
raised `NSInvalidArgumentException` because the decoded string does
not respond to `preferenceForKey:withCharacter:`. The probe source and
output are in `/tmp/atlantis-world-load-review.NMsMnO`.

Evaluate how to report invalid files, retain valid worlds when a
directory contains mixed entries, and handle default seeding when
every existing archive is rejected. Keep the failing files available
for recovery and verify loading existing world archives.

## Handle unterminated AML tags without throwing

At `b792ed6`, the [AML parser](../Extensions/NSAttributedStringAdditions.m)
detects a missing closing `>` but continues into the tag extraction.
The failed search leaves `NSNotFound` in the end range. Subtraction
using that location produces an out-of-bounds substring request.

To reproduce, run a script in a disposable profile with an open
spawn. Call `appendAMLToSpawnInWorld("hello <b", spawn, world)` using
the names of that spawn and world. A focused probe calling the same
production parser with `hello <b>world</b>` returned `hello world`.
With `hello <b`, it raised `NSInvalidArgumentException` from
`substringWithRange:`. The probe and output are in
`/tmp/atlantis-aml-review.8uBIuh`.

Decide how to handle the unfinished tail and test the chosen behavior
through spawn output, status text, and event-line replacement. Keep
the valid markup and entity-decoding cases covered.

## Clarify whether the spawn status-text API accepts AML

The [JavaScript scripting guide](JavaScriptScripting.md) describes
`setStatusBarTextForSpawnInWorld(text, spawn, world)` as setting
status-bar text. The [bridge implementation](../Scripting/ScriptBridge.m)
passes that string to the AML parser, so markup and entity references
have formatting and decoding effects in an API described as text.

To reproduce in an open spawn, call
`setStatusBarTextForSpawnInWorld("A &lt; B", spawn, world)` with
the actual names. A plain-text contract would display `A &lt; B`.
The AML parser decodes it to `A < B` before the bridge sets the
status text. A value such as `<b>status</b>` similarly renders as
formatted `status` through the current parser.

Determine whether to document AML as the supported input, provide a
separate AML API, or make this API literal. Check existing script
compatibility and verify the actual status bar for both plain text
and markup before changing the contract.

## Review newline and read boundaries in Grab and FugueEdit

At `e8a3724`, both editing paths in
[`handleOutput:`](../Worlds/RDAtlantisWorldInstance.m) subtract one
UTF-16 unit after removing the recognized prefix. This assumes the
last unit is a newline. The normal line splitter supplies a newline
for complete lines. In worlds configured as **MUD**, the receive
handler also sends the trailing part of each read to `handleOutput:`
without adding a newline so unterminated prompts can display. A
server can omit the newline, or the receive boundary can occur
before it or partway through the payload.

The **Grab** workflow starts with `/grab object/attribute` or
`/gname object`. It recognizes a reply starting with `1234` plus
the configured Grab password and a space. **FugueEdit** requires
**Support FugueEdit input-grabbing** in General preferences and
recognizes `FugueEdit > ` at the start of server output. Both paths
put text into the main input field for the user to edit.

To reproduce the range behavior, use either prefix in the table
and append each payload exactly as shown. A focused probe can
evaluate the production range expression on each input and compare
its result against the input length before taking the substring.
To exercise the receive path, use a disposable MUD world and a
local fixture server. Enable the corresponding editing feature.
Send the prefix and payload in a single write without a newline,
and wait until Atlantis processes it before sending any remaining
text. Use a fresh connection for each case.

| Prefix | Payload after the prefix |
| --- | --- |
| `1234example ` with Grab password `example` | `name target\n`, `name target`, or empty |
| `FugueEdit > ` with FugueEdit enabled | `name target\n`, `name target`, or empty |

The probe extracted `name target` when the payload ended in LF and
`name targe` when it did not. A prefix-only input produced a range
starting at the end of the input with length `NSUIntegerMax`.
The probe and output are in `/tmp/atlantis-grab-range-review.e7X0IX`.
The receive-path steps are based on code inspection.

Before changing behavior, verify which games send these editing
responses without LF and whether users expect complete payloads to
be recognized across reads. Decide how to treat prefix-only and
partial input, and preserve the normal prompt behavior for MUD
worlds. Batch 56 preserves extraction behavior while widening the
prefix lengths.
