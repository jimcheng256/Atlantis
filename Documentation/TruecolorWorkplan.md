# Truecolor workplan

Scope is inbound ANSI Truecolor for Atlantis. Outbound color authoring and
AML round trips are outside this workplan.

## Status as of 2026-11-26

| Increment | Status | Verification |
| --- | --- | --- |
| 1. ANSI compatibility baseline | Pushed in `d4cb315` | ANSI-free, 8-, 16-, and 256-color fixtures passed before and after the parser change. |
| 2. RGB parsing and rendering | Pushed in `d4cb315` | Hosted tests covered both syntaxes, style transitions, malformed input and diagnostic throttling, and a split RGB prompt in a hosted output pane. |
| 3. HTML log export | Pushed in `98b1868` | WebKit rendered both exports with exact RGB. Plain and formatted logs passed text-only checks. |
| 4. MTTS advertisement | Approved and pending commit | Hosted tests verified TTYPE replies and resets. Live probes confirmed all three negotiated modes. The full hosted suite reported 54 passed, 1 skipped, and 0 failures. |

## Planned scope by increment

1. Characterize existing ANSI-free, basic 8-color, bright 16-color, and
   indexed 256-color output through the normal ANSI filter. Check text and
   attributed runs with a custom palette, mixed styles, resets, and split
   sequences, including output without a trailing newline.
2. Parse semicolon and colon RGB foreground and background sequences. Keep
   explicit sRGB distinct from palette indexes and default colors. Verify
   transitions among all color modes, bold, underline, inverse, individual
   resets, and full reset. Log invalid syntax and malformed color groups
   with bounded NSLog diagnostics. Verify recovery and ensure incomplete
   chunks do not log prematurely. Run the hosted suite and stop for review.
3. Revise HTML logs separately. Preserve the existing palette classes in
   stylesheet mode. Verify both HTML modes with exact RGB, mixed channels,
   repeated colors, and resets, including a browser rendering check. Verify
   the text log formats stay text-only. Existing extended-palette fidelity
   in stylesheet mode is outside this change.
4. Advertise MTTS Truecolor once the renderer is ready. Check TTYPE replies
   and reconnect behavior with a controlled Telnet fixture. Verify RGB input
   without negotiation. For live testing, connect to last-outpost.com:4000
   as baudtest in fresh sessions for ANSI, indexed, and Truecolor. Record
   what Atlantis advertises, which mode the server selects, and what renders.
   Report any mode that could not be verified.

Run the focused hosted tests with the shared Atlantis scheme and
`-only-testing:AtlantisTests/ANSIColorTests`, then run the full hosted suite.

## Parser behavior

Atlantis accepts 8-bit sRGB channels in SGR `38;2;R;G;B` and
`48;2;R;G;B` and their colon-delimited forms. The optional colon color
space is either empty or zero. Explicit RGB uses the existing AppKit
foreground and background attributes. Indexed colors still use the
configured palette where applicable.

Malformed color groups preserve the prior color. The filter consumes the
group's expected operands before resuming SGR parsing. If a semicolon
group has an unknown mode, parsing resumes with the next escape sequence
because the group has no reliable boundary. Incomplete CSI input is held
for the next chunk. The Atlantis process log records up to five ANSI
diagnostics per filter in a ten-second window.

## HTML log behavior

Both HTML modes preserve explicit RGB as exact sRGB hex values. Stylesheet
mode combines existing palette classes with inline declarations for RGB
foreground or background. Inline mode writes both colors on each span so
adjacent spans with the same color render consistently. The hosted tests
open the generated files in WebKit and check computed colors, and verify
that plain and formatted logs still write text.

## Telnet advertisement and live verification

Atlantis keeps `Atlantis` and `xterm-256color` as its first two TTYPE
replies, then sends `MTTS 269` twice. The hosted fixture exercises the
actual Telnet filter, checks the reply bytes, and verifies that reconnecting
or disabling TTYPE restarts the sequence. The hosted rendering tests also
exercise RGB input without negotiation.

On 2026-11-26, a Telnet probe logged in to `last-outpost.com:4000` as
`baudtest` with three profiles:

| Second terminal type | MTTS | Mode reported at login | Color sequences received |
| --- | --- | --- | --- |
| `ANSI` | `5` | 16 Indexed | Basic ANSI and low palette indexes |
| `xterm-256color` | `13` | 256 Colors | Extended palette indexes |
| `xterm-256color` | `269` | Truecolor | Semicolon RGB sequences |

The server can prompt for a name before it completes TTYPE. In the
initial probes, sending the name after the first two TTYPE replies
selected 8 Indexed in all three sessions. Waiting until the final MTTS
reply was sent yielded the modes above. Live verification used a
protocol probe. Rendering was verified separately in the hosted app.
