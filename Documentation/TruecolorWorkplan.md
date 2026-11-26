# Truecolor workplan

Scope is inbound ANSI Truecolor for Atlantis. Outbound color authoring and
AML round trips are outside this workplan.

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
