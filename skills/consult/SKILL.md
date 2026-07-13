---
name: consult
description: Cross-model consultation and cheap batch delegation — get a second opinion from GPT (codex CLI) or other provider CLIs, or run mechanical batch work on a cheap model. Load when a review deserves cross-model diversity, when stuck on a hard problem, or when delegating large mechanical batches.
---

# Consult — Cross-Model Second Opinions & Cheap Batches

Model-tier doctrine: expensive models make decisions, cheap models type, and a *different* vendor's model reviews. Same-model review shares the same blind spots; cross-model diversity is the point.

## Second opinions (GPT via codex CLI)

The `/codex` skill (installed globally via gstack) wraps the OpenAI Codex CLI:

- **Review mode** — independent diff review with pass/fail: use after code-reviewer on high-stakes diffs (DSP cores, threading changes, state versioning).
- **Challenge mode** — adversarial "try to break this": use on lock-free/concurrency code before merge.
- **Consult mode** — ask with session continuity: use when stuck after bug-investigator has reported.

When both Claude review and codex review flag the same line independently, treat it as near-certainly real.

## Other provider CLIs

If installed, invoke the same way (Bash, non-interactive):

```bash
gemini -p "<question>"                       # Gemini CLI
ollama run qwen3-coder "<task>"              # local Qwen — free batch work
```

Check availability with `which gemini ollama codex` before offering; degrade gracefully to Anthropic-tier agents when absent.

## Cheap batch delegation

Mechanical work (renames across files, boilerplate from a spec, formatting sweeps, test scaffolds from a written spec) goes to the **mechanic** agent (haiku) or a local model — with the complete spec, serially, never in parallel with other writers. Decision-shaped work never goes to a cheap tier: if the task requires choosing, it stays with the main session.

## Cost discipline

- Don't consult reflexively — a second opinion on a one-line fix is waste. Triggers: audio-thread concurrency, state-format changes, releases, or being stuck.
- One consultation round, then decide. Endless cross-model ping-pong burns tokens without converging.
