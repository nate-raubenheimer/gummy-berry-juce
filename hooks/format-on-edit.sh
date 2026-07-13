#!/usr/bin/env bash
# gummy-berry-juce: auto-apply clang-format to edited C++ files.
# Harness-agnostic: reads hook JSON from stdin, accepts both Claude Code
# (snake_case, matcher-filtered) and VS Code Copilot (camelCase, no matchers).
set -u

INPUT="$(cat)"

FILE_PATH="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool = d.get("tool_name") or d.get("toolName") or ""
if tool not in ("Edit", "Write", "MultiEdit"):
    sys.exit(0)  # VS Code ignores matchers; filter here
ti = d.get("tool_input") or d.get("toolInput") or {}
print(ti.get("file_path") or ti.get("filePath") or "")
' 2>/dev/null)"

[ -n "${FILE_PATH:-}" ] || exit 0
case "$FILE_PATH" in
  *.cpp|*.h|*.hpp|*.cc|*.cxx) ;;
  *) exit 0 ;;
esac
[ -f "$FILE_PATH" ] || exit 0

# Skip generated/vendored code
case "$FILE_PATH" in
  */build/*|*_artefacts/*|*/JuceLibraryCode/*|*/JUCE/*|*/modules/*) exit 0 ;;
esac

if command -v clang-format >/dev/null 2>&1; then
  clang-format -i "$FILE_PATH" 2>/dev/null
fi
exit 0
