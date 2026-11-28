# JavaScript scripting

JavaScript scripting is enabled by default. The checkbox in **Preferences →
General → Experimental** controls whether Atlantis loads the JavaScript
engine at launch. Restart Atlantis after changing it.

Atlantis uses JavaScriptCore to run local JavaScript. Put UTF-8 `.js` files
in `~/Library/Atlantis/Scripts` or a subdirectory. Atlantis evaluates the
files at startup in path order. They share one global context, so give
handlers unique names or group them in objects. A file can contain functions
and top-level setup code.

Atlantis checks for added, modified, and removed script files when processing
input. When it detects a change, it rebuilds the context, removes existing
JavaScript event registrations, and evaluates the files again. JavaScript
globals are reset during this reload. File and execution errors appear in
the Atlantis process log. An error in one file allows subsequent files to load.
`console.log()`, `console.warn()`, and `console.error()` write to that log.

## Calling a script

Choose **JavaScript** in the **Script: Execute script function** action.
Enter a function name, a call such as `myGame.greet("Ada")`, or a JavaScript
snippet. A bare identifier that evaluates to a function calls it with no
arguments. For a command event, a bare function name receives the full
command argument string. An explicit call uses its specified arguments.

A game script can also register a handler at load time. This example shows a
status message when a line in the world named `Example MUD` matches the pattern.

```javascript
function exampleWelcome() {
    const world = AtlantisState["world.name"];
    ScriptBridge.sendStatusToSpawnInWorld(
        "Welcome back.",
        AtlantisState["event.spawn"] || world,
        world
    );
}

ScriptBridge.registerFunctionForLinePatternWithLanguageInWorld(
    "exampleWelcome()", "^Welcome back,", "JavaScript", "Example MUD"
);
```

During a call, `AtlantisState` is a snapshot of the current event. The keys
depend on the event and include `world.name`, `event.cause`, `event.line`,
`event.spawn`, and `event.uuid`. Use bracket notation for dotted keys.
Global temporary variables appear under `temp.<key>`. Use `ScriptBridge` to
change Atlantis data. At file load time the snapshot is empty. A call can
return a JavaScript value to the native caller. An exception or an
`undefined` result returns no native value.

## Timers

Timers use the browser-style signatures below. Delays are in milliseconds
and default to zero when omitted. A zero or negative delay schedules work
for a later turn of Atlantis's main run loop. Actual firing times depend on
when the app can process the callback. [HTML timer reference](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#timers)

| Function | Effect |
| --- | --- |
| `setTimeout(handler, delay, ...args)` | Run the handler once and return a numeric timer ID. |
| `setInterval(handler, delay, ...args)` | Run the handler repeatedly and return a numeric timer ID. |
| `clearTimeout(id)`, `clearInterval(id)` | Cancel a pending timer. Either function can clear either kind of timer. Unknown IDs have no effect. |

A handler can be a function or a JavaScript source string. Function handlers
receive the supplied arguments and run with `globalThis` as `this`. String
handlers run as global JavaScript. Reloading scripts cancels timers from the
previous runtime.

Timer callbacks start with an empty `AtlantisState` because they run outside
the event that scheduled them. Capture the values you need when you schedule
the callback.

```javascript
const world = AtlantisState["world.name"];
const timer = setTimeout((name) => {
    ScriptBridge.sendStatusToSpawnInWorld("Reminder", name, name);
}, 1500, world);

// Call clearTimeout(timer) to cancel the reminder.
```

## ScriptBridge API

JavaScriptCore joins the Objective-C selector components into camel case.
Pass arguments in the order shown. Names in the `world` position identify
a world by name. Use `worldUuidForName` for methods that take a `uuid`.
Use an empty character string to address world-level preferences.

### Worlds, input, and output

| Method | Effect |
| --- | --- |
| `sendTextToWorld(text, world)` | Send text to a connected world. |
| `sendAsInputOnWorld(text, world)` | Run text through Atlantis input processing. |
| `sendStatusToSpawnInWorld(text, spawn, world)` | Write a status line to a spawn. |
| `getTextFromInput()`, `sendTextToInput(text)` | Read or replace the focused input. |
| `getTextFromInputForSpawn(spawn)`, `setTextToInputForSpawn(text, spawn)` | Read or replace input for a specific spawn. |
| `focusSpawn(spawn)`, `selectedStringInSpawn(spawn)` | Focus a spawn or read its selected output. |
| `setStatusBarTextForSpawnInWorld(text, spawn, world)` | Set a spawn's status bar text. |
| `appendHTMLToSpawnInWorld(html, spawn, world)`, `appendAMLToSpawnInWorld(aml, spawn, world)` | Append formatted output. |
| `replaceEventLineInSession(aml, session)` | Replace the current event line. |
| `setLineSpawnCopyInSession(spawn, copy, session)` | Route the current line to a spawn. Pass `"1"` to copy or `"0"` to move. |
| `setPrefixForSpawnInSession(prefix, spawn, session)` | Set the input prefix for a spawn in the event world. |
| `uploadTextfileToWorld(path, world)`, `uploadCodefileToWorld(path, world)` | Upload a local file with Atlantis's text or code uploader. |

Pass `AtlantisState["event.uuid"]` for the session argument while the
event is running. Line replacement and routing are intended for line events.

### Variables, preferences, and connections

| Method | Effect |
| --- | --- |
| `setTemporaryVariableForKey(value, key)` | Write a global temporary variable using an unprefixed key. |
| `setVariableForKeyInWorld(value, key, world)` | Write a variable with a `temp.`, `worldtemp.`, or `userconf.` key. |
| `getPreferenceInWorld(key, world)`, `setPreferenceForKeyInWorld(value, key, world)` | Read or write a preference for the connected world and its current character. |
| `getPreferenceInWorldUUIDWithCharacter(key, uuid, character)` | Read a preference with world-level fallback. |
| `setPreferenceForKeyInWorldUUIDWithCharacter(value, key, uuid, character)` | Write a preference for the specified scope. |
| `removePreferenceInWorldUUIDWithCharacter(key, uuid, character)` | Remove a preference from the specified scope. |
| `worldUuidForName(world)` | Return the world's UUID or an empty string. |
| `charactersForWorld(uuid)` | Return the configured character names. |
| `isWorldConnectedForCharacter(uuid, character)` | Return `"1"` for a connection or `"0"` otherwise. |
| `connectWorldForCharacter(uuid, character)`, `disconnectWorldForCharacter(uuid, character)` | Open or close the specified connection. |

### Notifications and sound

| Method | Effect |
| --- | --- |
| `systemNotificationWithTitle(text, title)`, `growlTextWithTitle(text, title)` | Show a system notification. |
| `speakText(text)`, `systemBeep()`, `playSoundFile(path)` | Speak text, play the system beep, or play a local audio file. |

### Script registrations

Pass JavaScript source such as `"myHandler()"` for `script` and
`"JavaScript"` for `language`. Pass an empty world name for registrations
that apply to every world. The bridge accepts strings for timer and hotkey
numeric arguments, including `"1"` and `"0"` for the global hotkey flag.

| Method | Registration |
| --- | --- |
| `registerFunctionForLinePatternWithLanguageInWorld(script, pattern, language, world)` | Incoming line pattern. |
| `registerFunctionForEventTypeWithLanguageInWorld(script, eventType, language, world)` | Atlantis event type. |
| `registerAliasWithNameWithLanguageInWorld(script, alias, language, world)` | Input alias. |
| `registerTimerWithLanguageInWorldWithIntervalRepeats(script, language, world, seconds, repeats)` | Timer interval and repeat count. Use `"-1"` to repeat indefinitely. |
| `registerHotkeyFunctionWithKeyCodeModifiersGloballyWithLanguage(script, keyCode, modifiers, globally, language)` | Local or global shortcut using the native key code and modifier mask. |

## Template expansion length limits

In text templates that support variable expansion, `%{name:N}` keeps up
to `N` extended grapheme clusters from the expanded value. A combining
sequence such as `é` or a joined emoji such as `👩‍💻` counts as one.
The limit counts characters independently of font and display width.
Atlantis appends three dots when it omits text. The dots are additional
to the limit. Zero leaves the value in full, and a negative limit logs a
warning and behaves like zero.

### Follow-up: Comprehensive text expansion reference

- [ ] Trace `expandWithDataIn:` and its callers, then document every
  supported expansion form, variable namespace, and template field.
  Trace where each caller populates its lookup data so the reference can
  explain which names are available in each context. Cover lookup
  precedence, temporary-variable fallback, command arguments, regex
  captures, date and time fields, missing or malformed expressions,
  and grapheme-cluster limits. Verify examples against the current
  implementation and reconcile them with the legacy Atlantis Guide.

## Hosted tests

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  -only-testing:AtlantisTests/JSScriptingEngineTests test
```
