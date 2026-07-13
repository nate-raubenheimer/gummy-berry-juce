---
name: plugin-planning
description: Contract-first planning for a new plugin or major feature. Produces immutable spec files (creative brief, parameter spec, architecture, UI spec, plan) in docs/contracts/ that every build stage and reviewer works from. Use before writing any code in the full lane (/new-plugin, /feature).
---

# Plugin Planning — Contract-First

Purpose: eliminate drift. Every downstream stage (DSP, UI, review) reads these files — **the actual files, never a paraphrase**. Once the build starts, contracts are immutable; changing one is an explicit re-planning event, not an edit.

## Process

Interview the user until each contract can be written without guessing. Push back on scope. Then write, in order:

### 1. `docs/contracts/brief.md`
- What the plugin/feature is, in one paragraph a musician would understand
- Sonic goal & references (tracks, hardware, competitor plugins)
- Target user and use context; what it deliberately does NOT do
- Success criteria ("done when...")

### 2. `docs/contracts/parameters.md` — the most load-bearing contract
A table, one row per parameter:

| id | name | type | range | default | skew/steps | units | smoothing | automatable | notes |

Rules: ids are `snake_case`, stable forever, versioned `ParameterID{id, 1}`. Ranges in real-world units with correct skew (log for freq, dB for gain). Every audible parameter states its smoothing time. This file is the single source of truth — APVTS layout, UI bindings, and preset schema all derive from it mechanically.

### 3. `docs/contracts/architecture.md`
- Signal flow diagram (text/mermaid): input → stages → output
- DSP units: each with its algorithm choice, and whether it comes from `juce::dsp`, `chowdsp_utils`, or is hand-rolled (justify hand-rolling)
- Thread map: what runs where, every audio↔UI communication channel named (atomic/FIFO/handover) per [standards/10-realtime-rules.md](../../standards/10-realtime-rules.md)
- Latency sources; oversampling decisions; state/preset strategy

### 4. `docs/contracts/ui.md`
- Layout description or reference to Figma/mockups
- Every control mapped to a parameter id from parameters.md (bijection check: no orphan controls, no unbound parameters unless listed as internal)
- Metering/visualization data needs → each named as an audio→UI channel in architecture.md
- Shared component-library controls used; size, resizability

### 5. `docs/contracts/plan.md`
Staged build plan: **shell → DSP → UI → validate**, each stage a checklist of tasks small enough to complete and gate independently. Each stage ends with: gate passes (`scripts/gate.sh`) + code-reviewer pass against these contracts. Note per-task delegation: mechanical items marked for the mechanic agent, research items for the researcher.

## Rules

- No code before contracts are complete and user-approved.
- If mid-build reality contradicts a contract, STOP: surface it, re-plan explicitly, update the contract with a changelog note.
- Prior research (market/feasibility reports) feeds the brief; link it, don't duplicate it.
