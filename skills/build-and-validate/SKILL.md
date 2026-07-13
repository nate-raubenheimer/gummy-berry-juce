---
name: build-and-validate
description: Build, test, and validation workflow for gummy-berry JUCE projects — CMake configure/build, running the gate (build, clang-tidy, Catch2, pluginval), interpreting failures, and CI. Load when building, running the gate, or debugging build/validation failures.
---

# Build & Validate

Structure/conventions: [standards/20-cmake-structure.md](../../standards/20-cmake-structure.md). CI/signing: [standards/50-ci-release.md](../../standards/50-ci-release.md).

## Daily loop

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DGB_JUCE_PATH="$HOME/JUCE" \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build --parallel                 # or --target MyPlugin_Standalone
open "build/MyPlugin_artefacts/Debug/Standalone/MyPlugin.app"   # fastest iteration
```

## The gate — `scripts/gate.sh`

Run before claiming ANY task done. It is blocking and sequential:

1. Configure + build **Release with warnings-as-errors**
2. **clang-tidy** over project sources (uses compile_commands.json)
3. **CTest** (Catch2 suite)
4. **pluginval --strictness-level 10** on the built VST3

A gate failure is the task not being done — never argue with it, never weaken it to pass. If a tool is missing, install it (`brew install cmake clang-format llvm && brew install --cask pluginval`); the gate fails loudly rather than skipping.

## Interpreting common failures

| Symptom | Usual cause |
|---|---|
| pluginval hangs/times out | Deadlock or blocking wait in processBlock/prepareToPlay — check locks first |
| pluginval state-restore fail | get/setStateInformation asymmetry, or parameter added without new ParameterID version |
| Works Debug, fails Release | UB (uninitialized read, aliasing) — run the ASan/UBSan test build before guessing |
| AU not showing in Logic | Bundle ID/manufacturer code collision, or stale AU cache: `killall -9 AudioComponentRegistrar` |
| Random CI-only failures | Assumed block size / channel count / sample rate — see spec-test matrix in [standards/30-testing.md](../../standards/30-testing.md) |

## Rules

- Never edit generated files (`build/`, `*_artefacts`, JuceLibraryCode) — fix the source (CMake or contracts).
- Never commit with a red gate; the pre-commit hook enforces format + RT-scan, CI enforces the rest.
- Build failures you can't root-cause in two attempts → dispatch **bug-investigator**, don't loop.
