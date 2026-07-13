---
description: Full lane — scaffold a new JUCE plugin from the gummy-berry template and run the contract-first pipeline (brief → parameters → architecture → UI → staged build with gates)
argument-hint: <plugin name> [short description]
---

Build a new JUCE plugin: **$ARGUMENTS**

Follow the full lane, strictly in order:

## 1. Plan (contracts first — no code)
Load the **plugin-planning** skill and produce all five contracts in `docs/contracts/` (brief, parameters, architecture, ui, plan). Interview the user; incorporate any existing research documents they point at. Get explicit user approval of the contracts before proceeding.

## 2. Scaffold
Copy the `template/` directory from the gummy-berry-juce plugin root into the target project directory, substituting the plugin name, bundle id, and plugin code. Verify the bare scaffold configures and builds (`cmake -B build -DGB_JUCE_PATH="$HOME/JUCE" && cmake --build build`) before writing any feature code.

## 3. Staged build — sequential, gated
Stages: **shell → DSP → UI → validate**. For each stage:
- Load the relevant skill (**rt-safety** always for shell/DSP; **dsp-design** for DSP; **juce-ui** for UI; **build-and-validate** throughout).
- Implement against the contracts — the actual files, never from memory.
- Delegate fully-specified mechanical batches to the **mechanic** agent (serially); dispatch **researcher** for JUCE API/DSP literature questions.
- End of stage: run `scripts/gate.sh` (must pass), then dispatch **code-reviewer** on the stage diff with paths to the contract files. BLOCK verdicts are fixed before the next stage.

## 4. Validate & wrap
Final gate + code-reviewer pass over the whole diff. For DSP cores or concurrency-heavy code, use the **consult** skill for a cross-model second opinion. Confirm the parameter set in the built plugin matches `docs/contracts/parameters.md` exactly. Log any newly-discovered pitfall to the framework's `docs/critical-patterns.md`.

Rules: one writer at a time — never parallel edits. Contracts are immutable mid-build; if reality contradicts one, stop and re-plan explicitly with the user.
