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
