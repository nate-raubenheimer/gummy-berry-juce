# gummy-berry-juce

An agent framework for building JUCE audio plugins and instruments with CMake, packaged as a Claude Code plugin. It systematizes AI-assisted plugin development: enforced modern-C++/real-time standards, a contract-first build pipeline, hard quality gates, and cost-tiered specialist agents.

## Design in one paragraph

One writer, many specialists, hard gates. The main session plans and writes all production code, loading **skills** (DSP design, WebView UI, RT-safety, planning, build/validate) for domain expertise. **Read-only subagents** handle what genuinely benefits from context isolation: research, fresh-eyes code review, and bug root-cause analysis; a cheap **mechanic** agent takes serial mechanical batches. Quality is enforced in tiers: instant hooks (clang-format, RT-safety scan on every edit), a blocking gate (`build -Werror` → clang-tidy → Catch2 → pluginval 10), and advisory taste in skills. New plugins and major features go through an immutable **contract pipeline** (brief → parameter spec → architecture → UI spec → plan) so every stage and reviewer works from the same specs, never a paraphrase.

## Layout

| Path | What |
|---|---|
| `standards/` | The enforced reference: RT rules, CMake structure, testing, style, CI |
| `skills/` | Domain expertise loaded on demand (planning, rt-safety, dsp, ui, build, consult) |
| `agents/` | researcher · code-reviewer · bug-investigator · mechanic (read-only/serial, model-tiered) |
| `commands/` | `/new-plugin` `/feature` (full lane) · `/fix` (light lane) · `/gate` |
| `hooks/` | Harness-normalized edit hooks: format-on-edit, rt-safety-check |
| `template/` | Canonical plugin skeleton: JUCE 8 + CMake + WebView UI + Catch2 + gate + CI |
| `docs/` | DESIGN.md (architecture & rationale) · critical-patterns.md (living mistake DB) |

## Install

```bash
# marketplace-style local install
claude plugin marketplace add ~/Projects/"Gummy Berry JUCE"
claude plugin install gummy-berry-juce@gummy-berry
```

Local tooling the gate expects: `brew install cmake clang-format llvm && brew install --cask pluginval`.

## Harness portability

Knowledge is plain markdown; enforcement that matters is harness-neutral (git pre-commit, `gate.sh`, CI). VS Code / Copilot reads `.claude/skills`, `.claude/agents`, `CLAUDE.md`, and Claude-format hooks natively, so scaffolded projects work in both harnesses. See `docs/DESIGN.md`.
