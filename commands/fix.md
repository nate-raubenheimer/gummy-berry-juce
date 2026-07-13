---
description: Light lane — bug fix or small change with no contracts, but all quality gates still apply. Root cause before any fix.
argument-hint: <bug or small change description>
---

Light-lane change: **$ARGUMENTS**

No contracts, no ceremony — but the gates are not optional.

1. **Root cause first.** If this is a bug and the cause isn't already proven, dispatch **bug-investigator** and wait for its report. Iron law: no fix without a diagnosed root cause — symptom-patching is how plugins accumulate haunted code. Skip this only for trivial, self-evident changes (typo, label, obvious off-by-one with a failing test in hand).
2. **Regression test before fix** (bugs): write the test that reproduces the bug, watch it fail, then fix, watch it pass.
3. **Implement** minimally. Touching anything in the audio-thread call graph → load the **rt-safety** skill first. Stay in scope: unrelated problems get reported, not fixed.
4. **Gate**: run `scripts/gate.sh` — must pass. If audio-thread files changed, dispatch **code-reviewer** on the diff (RT-safety focus).
5. If the bug class is generalizable, append an entry to the framework's `docs/critical-patterns.md`.
