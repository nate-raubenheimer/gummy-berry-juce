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
