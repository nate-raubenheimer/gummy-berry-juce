# CMake & Project Structure

CMake only — **no Projucer**. JUCE 8, CMake ≥ 3.25, C++20.

## Canonical layout (the template)

```text
MyPlugin/
├── CMakeLists.txt          # everything below wired up
├── VERSION                 # single source of truth: "0.1.0"
├── AGENTS.md               # agent instructions (source of truth)
├── CLAUDE.md               # "@AGENTS.md" import + Claude-only notes
├── src/                    # C++ sources (SharedCode target)
├── ui/                     # WebView UI: index.html, css/, js/
├── tests/                  # Catch2 tests (link SharedCode, not the plugin)
├── docs/contracts/         # immutable specs: brief, parameters, architecture, ui
├── scripts/                # gate.sh, pre-commit
└── .github/workflows/      # CI
```

## Core CMake rules

1. **`juce_add_plugin` gets full metadata at call time** — never mutate target properties afterwards:

```cmake
juce_add_plugin(${PROJECT_NAME}
    COMPANY_NAME "Marula Music"
    BUNDLE_ID com.marulamusic.${PROJECT_NAME}
    PLUGIN_MANUFACTURER_CODE Maru
    PLUGIN_CODE Gbp1                       # unique 4-char, first letter uppercase
    FORMATS VST3 AU Standalone             # AU is macOS-only; Standalone = fast dev loop
    IS_SYNTH FALSE                         # per plugin
    NEEDS_MIDI_INPUT FALSE
    COPY_PLUGIN_AFTER_BUILD TRUE
    PRODUCT_NAME "${PRODUCT_NAME}")
```

2. **SharedCode pattern** (Pamplejuce): plugin sources compile once into an interface/static-lib target consumed by both the plugin and the test binary. Tests link *your code*, not a plugin bundle.

3. **JUCE modules link `PRIVATE`** — `PUBLIC` risks duplicate module copies:

```cmake
target_link_libraries(SharedCode INTERFACE
    juce::juce_audio_utils juce::juce_dsp
    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags
    juce::juce_recommended_warning_flags)
```

4. **Warnings are errors on project code** (`-Werror`/`/WX`) — JUCE itself compiles as SYSTEM so its warnings don't gate you.

5. **Module config via compile definitions**: `JUCE_WEB_BROWSER=1` (WebView UIs need it), `JUCE_USE_CURL=0`, `JUCE_VST3_CAN_REPLACE_VST2=0`.

6. **`CMAKE_EXPORT_COMPILE_COMMANDS=ON` always** — powers clangd and clang-tidy.

7. **JUCE acquisition**: `GB_JUCE_PATH` (local checkout, e.g. `~/JUCE`) → `add_subdirectory`; otherwise CPM/FetchContent pins a JUCE 8 release tag. Never a system-wide install.

8. **CLAP (optional flag)** via [clap-juce-extensions](https://github.com/free-audio/clap-juce-extensions):

```cmake
if(GB_ENABLE_CLAP)
    clap_juce_extensions_plugin(TARGET ${PROJECT_NAME}
        CLAP_ID "com.marulamusic.${PROJECT_NAME}"
        CLAP_FEATURES audio-effect)
endif()
```

Caveat: `AudioProcessor::wrapperType` is `Undefined` in CLAP builds — don't branch on it.

9. **AAX**: deliberately not supported until a plugin needs Pro Tools (PACE signing ceremony not worth speculative support).

10. **WebView UI assets** are zipped into the binary via `juce_add_binary_data` (or `WebBrowserComponent::Resource` provider streaming from BinaryData). Dev builds may serve from disk behind a `GB_UI_DIR` flag; release always embeds.

## Format & platform policy

| Target | When |
|---|---|
| VST3 + AU + Standalone, macOS (arm64 + x86_64 for release) | Every build — the daily loop |
| VST3, Windows | CI only — must stay green, not part of local loop |
| CLAP | `-DGB_ENABLE_CLAP=ON` when wanted |
| AAX, Linux | Not until a real need exists |
