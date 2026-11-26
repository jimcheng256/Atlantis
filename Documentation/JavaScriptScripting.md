# JavaScript scripting

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

## Hosted tests

```sh
xcodebuild -project Atlantis.xcodeproj -scheme Atlantis -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  -only-testing:AtlantisTests/JSScriptingEngineTests test
```
