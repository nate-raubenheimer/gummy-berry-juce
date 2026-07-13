---
description: Full lane on an existing project — contract-first pipeline for a major feature (new DSP section, new UI area, parameter additions)
argument-hint: <feature description>
---

Add a major feature to the current plugin project: **$ARGUMENTS**

This is the full lane — use it when the feature adds/changes parameters, DSP structure, or UI areas. (For small fixes, `/fix` is the right lane.)

1. **Plan**: load the **plugin-planning** skill. Read the existing `docs/contracts/` first. Produce contract *updates* — new parameter rows (new `ParameterID` version hints if the plugin has shipped), architecture deltas, UI additions — as explicit, user-approved changes with a changelog note in each touched contract. If the project has no contracts yet (pre-framework project), write minimal ones covering the touched area before coding.
2. **Build**: staged as applicable (DSP → UI → validate), sequential, loading **rt-safety** / **dsp-design** / **juce-ui** per stage. Mechanical batches → **mechanic** (serial); lookups → **researcher**.
3. **Gate + review** after each stage: `scripts/gate.sh`, then **code-reviewer** on the diff against the updated contracts. Fix BLOCKs before proceeding.
4. **Regression check**: existing characterization tests must still pass unchanged unless the contract update explicitly authorizes a behavior change (then regenerate goldens as a reviewed decision).
