# Agent Instructions — GummyPlugin

This project is built with the **gummy-berry-juce** framework. These instructions bind every AI agent working here (Claude Code, VS Code chat, or any other harness).

## Non-negotiables

1. **Real-time safety**: no allocation, locks, I/O, or logging anywhere in the audio-thread call graph (`processBlock` and everything it reaches). The full rules and approved patterns are in the framework's `standards/10-realtime-rules.md`; the `rt-check` scan and code review enforce them.
2. **Contracts are law**: `docs/contracts/` (brief, parameters, architecture, ui, plan) is the source of truth. Parameter ids, ranges, defaults, and smoothing come from `docs/contracts/parameters.md` — never invent or change them ad hoc. Contract changes are explicit, user-approved re-planning events.
3. **The gate decides done**: `scripts/gate.sh` (build with warnings-as-errors → clang-tidy → tests → pluginval strictness 10 → ship-safety assertion) must pass before any task is complete. Never weaken the gate to pass it.
4. **Tests**: TDD for logic (parameters, state, MIDI); DSP may be prototyped freely but must ship spec + characterization tests before merge (matrix: 44.1/48/96 kHz × block sizes 1/16/333/4096, no NaN/inf/denormals).
5. **One writer at a time** — never parallel edits to this codebase.

## Project facts

- JUCE 8 + CMake (no Projucer). C++20. Formats: VST3, AU, Standalone (CLAP via `-DGB_ENABLE_CLAP=ON`).
- UI is a JUCE 8 WebView (`ui/` = HTML/CSS/JS); parameters bridge via relay + attachment pairs in `src/PluginEditor.cpp`. Dev hot-reload: set `GB_UI_DIR=$PWD/ui`.
- Local JUCE checkout: configure with `-DGB_JUCE_PATH="$HOME/JUCE"` to skip the network fetch.
- Build: `cmake -B build && cmake --build build`. Fast loop: the Standalone target.
- `.clang-format` is applied automatically — never hand-format. `build*/`, `ui/js/juce/`, and `ui/dist/` are generated — never edit. The WebView UI (`ui/js`, `ui/css`) is bundled by esbuild (`ui/build.mjs`) into `ui/dist/main.{js,css}`; CMake runs `npm run build` at configure time and reruns it at build time when UI sources change (no reconfigure needed).

## Workflow

- New major feature → full lane (contracts first). Small fix → light lane, but root-cause before fixing bugs, and the gate still applies.
- Bug you can't root-cause in two attempts: stop and investigate systematically — do not loop on speculative fixes.
- Every fixed bug gets a regression test written before the fix.
