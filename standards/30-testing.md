# Testing Doctrine

## The two-mode rule

| Code type | Doctrine |
|---|---|
| **Logic** — parameter handling, state save/load, MIDI transforms, routing, preset management | **Test-first (TDD).** Specs are knowable upfront; write the failing test, then the code. |
| **DSP** — anything you voice by ear | **Prototype freely, then spec-test before merge.** Test-first on unvoiced DSP produces fake tests. Once it sounds right, the tests lock it down. |

**Nothing merges untested.** The gate (`scripts/gate.sh`) runs the full suite; a DSP unit without its spec tests fails review.

## Required tests for every DSP unit

Run each across sample rates **44.1k / 48k / 96k** and block sizes **1, 16, 333, 4096** (hosts send anything, including 0-length blocks):

1. **Silence in → silence out** (or documented exception, e.g. reverb tails decay below −90 dBFS within spec).
2. **No NaN / inf / denormal in output** for white noise, impulse, DC, and full-scale sine inputs.
3. **Level bounds** — output within the unit's documented headroom for full-scale input.
4. **Frequency response** where meaningful — FFT of impulse response vs expected curve (tolerance ±0.5 dB unless specified).
5. **Reset correctness** — `prepareToPlay` → process → `reset` → process produces identical output (no leaked state).
6. **Characterization render** — golden-file comparison (with tolerance) of a reference input, locking behavior against regressions. Regenerate goldens only with an explicit, reviewed decision.

## Framework & structure

- **Catch2 v3** via CPM; tests are a separate target linking the SharedCode lib ([20-cmake-structure.md](20-cmake-structure.md)) and registered with CTest.
- **melatonin_test_helpers** for audio matchers (`isValidAudio()` etc.).
- Processor-level tests instantiate the `AudioProcessor` headlessly: `prepareToPlay` → feed known signals → assert. No GUI required.
- Logic tests (APVTS round-trips, state versioning, MIDI) live beside DSP tests; they are plain fast unit tests.

## Host-level validation

- **pluginval at strictness 10** is a merge gate, run by `gate.sh` locally and CI on every platform. Level 10 includes parameter fuzzing, state-restore, and threading checks.
- Install locally: `brew install --cask pluginval`.

## Sanitizers

| Sanitizer | Cadence |
|---|---|
| ASan + UBSan | Every CI run (test target) |
| TSan | CI job — catches audio/message-thread races |
| RTSan (`-fsanitize=realtime`, LLVM 20+) | CI where toolchain allows; `[[clang::nonblocking]]` on `processBlock` |

## Regression discipline

Every bug fixed gets a test that would have caught it, written **before** the fix (proves the test detects the bug), plus an entry in `docs/critical-patterns.md` if the bug class is generalizable.
