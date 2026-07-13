---
name: rt-safety
description: Real-time audio-thread safety rules and approved lock-free patterns for JUCE plugins. Load before writing or reviewing ANY code that runs on the audio thread (processBlock, prepareToPlay, DSP classes, parameter reads, metering).
---

# RT-Safety

The full rules live in [standards/10-realtime-rules.md](../../standards/10-realtime-rules.md) — read that file now. This skill adds the working method:

## Method

1. **Classify the code first** using the three-thread model in [standards/00-overview.md](../../standards/00-overview.md). If a function is reachable from `processBlock`, it is audio-thread code — the whole call graph inherits the rules.
2. **Choose the communication pattern from the approved toolbox** (atomics, SPSC FIFO, release-pool handover, APVTS raw pointers). Never invent a new concurrency mechanism; if none fits, use farbot/crill primitives and document why.
3. **Declare thread ownership** in the class comment: which members belong to which thread, which are shared and via what mechanism.
4. **Allocate everything in `prepareToPlay`** sized for worst case; `processBlock` only ever touches pre-allocated memory.
5. Before finishing, self-audit the diff against the banned-symbol list in 00-overview.md — the hook will scan it anyway, but catch it yourself first.

## Review checklist (used by code-reviewer)

- [ ] No allocation/locks/I-O anywhere in the audio call graph (including hidden: String, std::function, vector growth, shared_ptr destruction)
- [ ] `ScopedNoDenormals` + unused-channel clearing at top of processBlock
- [ ] No block-size or channel-count assumptions (0-length blocks handled)
- [ ] Parameters read via cached `getRawParameterValue` atomics; audible ones smoothed; smoothers reset in prepareToPlay
- [ ] All cross-thread traffic uses an approved pattern; memory ordering justified
- [ ] `static_assert(is_always_lock_free)` on every atomic type used
- [ ] Latency reported if introduced; state save/load on message thread only
- [ ] Nothing destroyed on the audio thread
