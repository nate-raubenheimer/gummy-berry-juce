---
name: juce-ui
description: WebView-first UI development for JUCE 8 plugins — WebBrowserComponent hosting, JS-C++ parameter bridge, resource embedding, meter polling, and shared component-library conventions. Load when building or modifying any plugin UI.
---

# JUCE UI — WebView-First

Doctrine: UIs are **HTML/CSS/JS hosted in `juce::WebBrowserComponent`** (JUCE 8). Native Components are the exception (heavy GL visualizers, minimal-footprint plugins) and need explicit justification.

## Structure

```text
ui/
├── index.html        # single page
├── css/              # styles — marula design language
└── js/               # bridge + controls; no build step unless the project opts in
```

Editor hosts the WebView with `WebBrowserComponent::Options` → `.withNativeIntegrationEnabled(true)` → resource provider serving from BinaryData (release) or disk (dev hot-reload flag `GB_UI_DIR`).

## Parameter bridge — the rules

- **Every control binds to a parameter id from `docs/contracts/parameters.md`** via JUCE's relay classes: `WebSliderRelay`/`WebToggleButtonRelay`/`WebComboBoxRelay` + matching `WebSliderParameterAttachment` etc. on the C++ side, and the JUCE frontend JS (`juce_gui_extra` ships `index.js` helpers) on the web side.
- Bijection check before finishing: no orphan UI controls, no unbound parameters (unless the contract marks them internal).
- Never invent ad-hoc `evaluateJavascript` parameter plumbing when a relay exists. Custom events (preset lists, file drops) use `emitEventIfBrowserIsVisible` / native functions — documented per event.

## Data to the UI (meters, analyzers)

Audio thread → atomic/FIFO → **message-thread `juce::Timer`** (30–60 Hz) → single batched event to the WebView. Never per-sample events, never audio-thread emission ([rt-safety](../rt-safety/SKILL.md)).

## Component-library conventions

- If a shared UI component library exists (its location is named in the project's AGENTS.md/CLAUDE.md), reuse its controls/CSS before writing new ones; new generally-useful controls go back into it.
- Design source of truth: the project's design files / `docs/contracts/ui.md`. Match it; don't freelance aesthetics.
- Test in the Standalone build first (fastest loop), then verify in a real host — WebView sizing/focus behaves differently hosted.

## Native path (secondary)

When justified: Component + LookAndFeel, parameter binding via `SliderAttachment` etc., `JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR` on every component, no work in `paint()` beyond drawing.
