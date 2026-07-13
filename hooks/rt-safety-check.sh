#!/usr/bin/env bash
# gummy-berry-juce: fast RT-safety scan on edited C++ files.
# Scans the bodies of realtime functions (processBlock / process / processSample /
# renderNextBlock / getNextAudioBlock) for banned operations. Exit 2 = blocking
# feedback to the agent. Harness-agnostic (snake_case + camelCase input).
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
    sys.exit(0)
ti = d.get("tool_input") or d.get("toolInput") or {}
print(ti.get("file_path") or ti.get("filePath") or "")
' 2>/dev/null)"

[ -n "${FILE_PATH:-}" ] || exit 0
case "$FILE_PATH" in
  *.cpp|*.h|*.hpp|*.cc|*.cxx) ;;
  *) exit 0 ;;
esac
[ -f "$FILE_PATH" ] || exit 0
case "$FILE_PATH" in
  */build/*|*_artefacts/*|*/JuceLibraryCode/*|*/JUCE/*|*/tests/*) exit 0 ;;
esac

python3 - "$FILE_PATH" <<'PY'
import re, sys

path = sys.argv[1]
try:
    src = open(path, encoding="utf-8", errors="replace").read()
except OSError:
    sys.exit(0)

RT_FUNCS = r"\b(processBlock|processSample|renderNextBlock|getNextAudioBlock|processBlockBypassed|process)\s*\("

BANNED = [
    (r"\bnew\b", "operator new (heap allocation)"),
    (r"\bdelete\b", "operator delete (deallocation)"),
    (r"\b(malloc|calloc|realloc|free)\s*\(", "C allocation"),
    (r"\bstd::(mutex|lock_guard|unique_lock|scoped_lock|shared_mutex)\b", "lock"),
    (r"\b(CriticalSection|ScopedLock|ScopedWriteLock|ScopedReadLock)\b", "JUCE lock"),
    (r"\bString\b", "juce::String usage (allocates)"),
    (r"\bstd::string\s*[({]", "std::string construction (allocates)"),
    (r"\bstd::function\b", "std::function (allocates on construction/assignment)"),
    (r"\.(push_back|emplace_back|resize|reserve|insert)\s*\(", "container growth (may allocate)"),
    (r"\bmake_(unique|shared)\b", "smart-pointer allocation"),
    (r"\bDBG\s*\(", "DBG logging"),
    (r"\b(Logger::|std::cout|std::cerr|printf|fprintf)\b", "logging/IO"),
    (r"\b(fopen|ifstream|ofstream|fstream)\b", "file IO"),
    (r"\bMessageManager::callAsync\b", "callAsync (allocates, message thread)"),
    (r"\bsendChangeMessage\b", "change broadcast from RT context"),
    (r"\b(sleep|usleep|nanosleep|wait_for|wait_until|condition_variable)\b", "blocking wait"),
    (r"\b(copyState|replaceState|getStateInformation|setStateInformation)\s*\(", "state ops (lock; message thread only)"),
]

def strip_comments(text):
    text = re.sub(r"//[^\n]*", "", text)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return text

findings = []
for m in re.finditer(RT_FUNCS, src):
    brace = src.find("{", m.end())
    if brace == -1:
        continue
    # Only definitions immediately following the signature (skip declarations)
    between = src[m.end():brace]
    if ";" in between:
        continue
    depth, i = 1, brace + 1
    while i < len(src) and depth:
        c = src[i]
        if c == "{": depth += 1
        elif c == "}": depth -= 1
        i += 1
    body = strip_comments(src[brace:i])
    base_line = src[:brace].count("\n") + 1
    fname = m.group(1)
    for pat, why in BANNED:
        for bm in re.finditer(pat, body):
            line = base_line + body[:bm.start()].count("\n")
            findings.append(f"  {path}:{line} in {fname}(): {why} — `{bm.group(0).strip()}`")

if findings:
    print("RT-SAFETY: banned operations detected in realtime function bodies:", file=sys.stderr)
    for f in findings[:20]:
        print(f, file=sys.stderr)
    print(
        "Rule source: gummy-berry-juce standards/10-realtime-rules.md. "
        "Fix using an approved pattern (preallocate in prepareToPlay, atomics, SPSC FIFO, release pool). "
        "If a match is a false positive (comment/string/non-RT overload), justify it explicitly.",
        file=sys.stderr,
    )
    sys.exit(2)
sys.exit(0)
PY
exit $?
