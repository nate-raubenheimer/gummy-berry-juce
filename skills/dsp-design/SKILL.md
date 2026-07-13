---
name: dsp-design
description: DSP design and implementation guidance for JUCE plugins — algorithm selection, juce::dsp and chowdsp_utils usage, smoothing, oversampling, denormals, and the prototype-then-spec-test workflow. Load when designing or implementing any audio processing.
---

# DSP Design

## Library-first rule

Never hand-roll what a maintained library does well. Selection order:

1. **`juce::dsp`** — `ProcessorChain`, IIR/FIR, `StateVariableTPTFilter`, `Convolution` (has built-in background loader), `FFT`, `Oversampling`, `LadderFilter`, `Compressor`/`Limiter`, `SIMDRegister`.
2. **`chowdsp_utils`** — when juce::dsp isn't enough: Butterworth/Chebyshev/SVF variants, linear-phase EQ, anti-aliased waveshapers, resamplers, SIMD buffers. Check module licenses (mixed BSD/GPL3).
3. **Hand-rolled** — only with justification in `docs/contracts/architecture.md` (novel algorithm, character/voicing, performance). Hand-rolled units get the strictest test coverage.

## Non-negotiable habits

- `juce::ScopedNoDenormals` in processBlock (FTZ/DAZ); denormal-prone feedback paths (filters, reverbs) still add a tiny DC offset or flush explicitly where FTZ can't reach.
- **Smooth every audible parameter** — `juce::SmoothedValue`, ramp time from the parameter spec. Zipper noise is a defect, not a nitpick.
- **Oversample nonlinear stages** (`juce::dsp::Oversampling`) — waveshapers/saturators alias without it; report added latency via `setLatencySamples()`.
- Coefficients recompute on parameter change, not per-sample; use `constexpr` tables where possible.
- Reset ALL state (filters, delays, smoothers, envelopes) in `prepareToPlay` and `reset()` — stale state across transport jumps is a classic bug.
- Process in `float`; use `double` only where numerically justified (filter coefficients at low frequencies, accumulation).

## Workflow: prototype → voice → lock

1. Design on paper in the architecture contract (signal flow, algorithm choices) first.
2. Prototype freely — Standalone format build is the fast loop; voice by ear.
3. When it sounds right, **lock it with spec tests** per [standards/30-testing.md](../../standards/30-testing.md): silence/NaN/level/frequency-response/reset tests + a characterization render. Only then merge.

## Consult, don't guess

For algorithm questions (filter topologies, BLEP/BLAMP, physical modeling, dynamics detector design), dispatch the **researcher** agent to find the actual literature/reference implementation rather than working from memory. Cite what you used in the architecture contract.

All audio-thread code obeys [rt-safety](../rt-safety/SKILL.md) — load it alongside this skill.
