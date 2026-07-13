---
description: Run the hard quality gate on the current plugin project (build -Werror → clang-tidy → tests → pluginval 10) and report results
---

Run the quality gate on the current project and report the results honestly.

1. Load the **build-and-validate** skill.
2. Run `scripts/gate.sh` from the project root. If the project predates the framework and has no gate script, copy it from the gummy-berry-juce plugin's `template/scripts/gate.sh` first.
3. Report each stage's outcome plainly (build / tidy / tests / pluginval), including the failing output verbatim on failure. Never summarize a failure as "mostly passing".
4. On failure: fix if the cause is evident and in scope; otherwise dispatch **bug-investigator**. Never weaken the gate (no skipping stages, no lowering pluginval strictness) to get a pass.
