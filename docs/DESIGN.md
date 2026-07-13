# gummy-berry-juce — Architecture & Rationale

Decided 2026-07-13 after a structured interview plus three research passes (multi-agent orchestration best practices; JUCE/modern-C++ standards; VS Code ↔ Claude Code compatibility). This document records *why* the framework is shaped the way it is, so future changes argue with the evidence rather than re-deriving it.

## Core thesis: one writer, skills as specialists, hard gates

The original vision was a seven-agent orchestra (planning, coding, review, DSP, research, bug-fix, UI). The research killed it:

1. **Parallelize reads, serialize writes.** Cognition's "Don't Build Multi-Agents" documents how parallel writer agents produce incompatible halves — each agent's code embodies decisions the other never saw. A plugin (`PluginProcessor` + `PluginEditor` + APVTS layout) is one tightly coupled system; a DSP agent and UI agent writing concurrently produce mismatched parameter layouts. Anthropic's multi-agent wins are all parallel *reading* (research), never parallel writing.
2. **Subagents provide context isolation, not expertise.** A "DSP agent" is the same model; what makes it expert is loaded knowledge — which is a **skill** the single writer can load while keeping full context.
3. **Cost:** subagent-heavy workflows run 7–15x tokens (Anthropic's own numbers).

So: the main session plans and writes everything, loading skills per domain. Subagents exist only where isolation genuinely pays:

| Agent | Model | Why isolation pays |
|---|---|---|
| researcher | sonnet | Keeps doc-dumps out of the main context; read-only |
| code-reviewer | inherit (Fable) | Fresh eyes that haven't watched the author rationalize; read-only |
| bug-investigator | opus | Deep root-cause dives without polluting the writer's context; read-only |
| mechanic | haiku | Cheap serial typing of fully-specified batches — cost tiering, not parallelism |

Cross-model second opinions (GPT via codex CLI, Qwen/Gemini CLIs) via the `consult` skill — different vendors have different blind spots.

## Contracts: the anti-drift mechanism

Summary-based handoffs lose decisions (the "telephone game"). The full lane therefore writes immutable contracts to `docs/contracts/` (brief, parameters, architecture, ui, plan) and every stage/reviewer reads the actual files. The parameter spec is the load-bearing one: APVTS layout, UI bindings, and preset schema all derive from it. Pattern adapted from plugin-freedom-system ("zero drift"), the strongest JUCE-specific prior art.

Two lanes because ceremony kills adoption: `/new-plugin` and `/feature` run the full pipeline; `/fix` skips contracts but keeps root-cause discipline and the gate.

## Enforcement tiers (evidence: hooks ≈ 100% compliance, instruction files ≈ 70–90%)

1. **Instant** — PostToolUse hooks: clang-format auto-apply + RT-safety scan of realtime function bodies on every C++ edit.
2. **Gate** — `scripts/gate.sh`, blocking: Release build with `-Werror` → clang-tidy → Catch2/CTest → pluginval strictness 10. CI adds ASan/UBSan and Windows.
3. **Advisory** — style/taste in skills and standards docs, weighed by the reviewer.

Anything that must *always* hold lives in tiers 1–2; CLAUDE.md/AGENTS.md carries only what tooling can't check.

## Harness portability

Verified July 2026: VS Code/Copilot natively reads `CLAUDE.md`, `.claude/skills/`, `.claude/agents/`, and Claude-format hooks from `.claude/settings.json`; Claude Code does **not** read `AGENTS.md` natively (hence the `@AGENTS.md` import in the template's CLAUDE.md). Consequences:

- **Author Claude-first** — skills/agents in Claude locations serve both harnesses. Don't create `.github/prompts` or `.chatmode.md` files (legacy).
- **AGENTS.md is the instruction source of truth** in scaffolded projects; CLAUDE.md is a one-line import plus Claude-only pointers.
- **Hook scripts are harness-normalized**: they parse both snake_case (Claude) and camelCase (VS Code) input and filter tool names in-script, because VS Code ignores matchers.
- **The binding enforcement is harness-neutral anyway**: git pre-commit (format + `scripts/rt-check.py`), `gate.sh`, and CI hold no matter what drives the editor.
- Known gaps if driving Copilot: Claude skill extensions (`allowed-tools`, `!` context injection, `context: fork`) degrade silently; model pinning uses different identifiers (BYOK Anthropic keys give the same underlying models).

## Model tiering (cost strategy)

Decisions are expensive to get wrong and cheap to buy well: planning/review on the strongest model; mechanical execution on the cheapest. Fable (main session) plans, writes, reviews; opus investigates; sonnet researches; haiku/Qwen types. Knowledge lives in portable markdown so nothing is coupled to a vendor.

## Template notes

- Pamplejuce-informed mechanics (VERSION file, Catch2+CTest, pluginval CI, warnings-as-errors) on Nate's proven `src/tests/ui/docs` conventions, WebView editor pattern lifted from Prisma (proven on this machine).
- Plugin + test targets compile the sources twice (Prisma-proven `juce_add_console_app` approach) — JUCE's plugin defines make true single-compile shared libs more trouble than the compile time saves at this project size.
- `ui/js/juce/` is synced from the JUCE checkout at configure time and gitignored.

## Deferred (explicitly)

- **Headless Agent-SDK runner** for unattended CI jobs — reuses the same skills/standards markdown.
- **AAX/Linux support**, Windows signing — until a plugin needs them.
- **Derived VS Code artifacts** (`.instructions.md` from rules, `.vscode/mcp.json`) — generate only if github.com-side Copilot surfaces are ever used.

## First validation target

Spook (MIDI plugin, research already in `~/Projects/Spook`) runs the full lane end-to-end; every friction point becomes a framework fix and a `critical-patterns.md` entry.
