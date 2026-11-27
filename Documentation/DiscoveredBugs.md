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
