# Critical Patterns — Living Mistake Database

Every generalizable bug, gotcha, or repeated agent mistake gets an entry here. Agents: read this before starting work on any plugin; append an entry whenever a failure teaches something reusable. Keep entries short — symptom, cause, rule.

Format:

```markdown
## <short title> (YYYY-MM-DD)
**Symptom:** what was observed
**Cause:** the actual mechanism
**Rule:** what to always/never do now
```

---

## WebView editor member order (2026-07-14)
**Symptom:** crash or missing relays when the WebBrowserComponent constructs.
**Cause:** `webView`'s constructor consumes `makeOptions()`, which reads the relay vectors — if `webView` is declared before the relays, they're consumed uninitialized.
**Rule:** in WebView editors, relay/attachment containers are declared **before** the `webView` member; `createRelays()` runs inside the ctor initializer via the comma operator (see template `PluginEditor.h`).

## CORS header for ES modules (2026-07-14)
**Symptom:** WebView UI loads but JS modules silently fail to import.
**Cause:** resource provider served without an `Access-Control-Allow-Origin` header; ES module loading enforces CORS even for provider-served resources.
**Rule:** always pass the allowed-origin argument (`juce::String ("*")`) to `withResourceProvider`.

## Stale JUCE APIs from training data (2026-07-14)
**Symptom:** generated code references JUCE symbols that don't compile.
**Cause:** models emit deprecated/renamed JUCE APIs from older training data.
**Rule:** verify any non-everyday JUCE symbol against the local checkout (`grep -r <symbol> ~/JUCE/modules/<module>/`) before using it; dispatch the researcher agent for anything unfamiliar.

## CFSTR on JucePlugin_CFBundleIdentifier needs JUCE_STRINGIFY (2026-09-15)
**Symptom:** `CFSTR (JucePlugin_CFBundleIdentifier)` fails with "expected ')'" in the real plugin target, but the same line compiles fine in a console-app test target.
**Cause:** `JucePlugin_CFBundleIdentifier` expands to a bare, unquoted dotted token (`com.company.plugin`), not a string literal — `CFSTR`'s macro body pastes its argument between two `""` and needs an actual string-literal token. The console test app never defines the macro at all, so it's silently skipped there (`#if defined (JucePlugin_CFBundleIdentifier)`), masking the bug until the real plugin target builds.
**Rule:** any macro-driven `JucePlugin_*` identifier that isn't already a string (check its `#define` — some are, some aren't) needs `JUCE_STRINGIFY (...)` before `CFSTR`/`juce::String` use, e.g. `CFSTR (JUCE_STRINGIFY (JucePlugin_CFBundleIdentifier))` (see `juce_CoreMidi_mac.mm` for JUCE's own reference usage). Don't trust a console-app-target compile as proof this code path works — it may not define the macro at all.

## clap_juce_extensions_plugin CLAP_FEATURES defaults to effect (2026-09-15)
**Symptom:** a CLAP instrument plugin loads in Bitwig (and presumably other CLAP hosts) as an audio **effect**, not an instrument — wrong track type, no MIDI input shown.
**Cause:** the template's `clap_juce_extensions_plugin(... CLAP_FEATURES audio-effect)` placeholder was copied as-is into an instrument project; CLAP categorizes plugins purely from this feature-tag list, independent of `IS_SYNTH`/`NEEDS_MIDI_INPUT` (those only affect VST3/AU).
**Rule:** for any instrument/synth project, set `CLAP_FEATURES instrument <subtype...> stereo` (e.g. `instrument drum sampler stereo`) — never leave the template's `audio-effect` default. `IS_SYNTH TRUE` does not propagate to the CLAP wrapper's category.

## bugprone-throwing-static-initialization on file-scope juce::StringArray (2026-09-15)
**Symptom:** clang-tidy gate fails (this project's config treats `bugprone-*` as hard errors) on lines like `const juce::StringArray choices { "A", "B" };` at anonymous-namespace/file scope.
**Cause:** any object with static storage duration whose constructor could throw (StringArray's can, via allocation) triggers this check, because an exception during static init before `main()` is unrecoverable.
**Rule:** don't cache small `juce::StringArray`/similar lookup tables as file-scope `const` globals in plugin source — build them as local variables inside the function that uses them (they're cheap; JUCE plugins call these constructor/layout paths rarely, not per-block), or make them non-static class members initialized in a constructor body.
