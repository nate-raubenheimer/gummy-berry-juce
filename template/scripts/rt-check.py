#!/usr/bin/env python3
"""Standalone RT-safety scan for pre-commit and CI (harness-neutral).

Scans realtime function bodies (processBlock / processSample / renderNextBlock /
getNextAudioBlock / process) for banned operations per the gummy-berry standards
(standards/10-realtime-rules.md). Usage: scripts/rt-check.py <file.cpp> [...]
Exit 1 if violations are found.
"""
import re
import sys

RT_FUNCS = re.compile(
    r"\b(processBlock|processSample|renderNextBlock|getNextAudioBlock|"
    r"processBlockBypassed|process)\s*\("
)

BANNED = [
    (re.compile(r"\bnew\b"), "operator new (heap allocation)"),
    (re.compile(r"\bdelete\b"), "operator delete (deallocation)"),
    (re.compile(r"\b(malloc|calloc|realloc|free)\s*\("), "C allocation"),
    (re.compile(r"\bstd::(mutex|lock_guard|unique_lock|scoped_lock|shared_mutex)\b"), "lock"),
    (re.compile(r"\b(CriticalSection|ScopedLock|ScopedWriteLock|ScopedReadLock)\b"), "JUCE lock"),
    (re.compile(r"\bString\b"), "juce::String usage (allocates)"),
    (re.compile(r"\bstd::string\s*[({]"), "std::string construction (allocates)"),
    (re.compile(r"\bstd::function\b"), "std::function (allocates)"),
    (re.compile(r"\.(push_back|emplace_back|resize|reserve|insert)\s*\("), "container growth (may allocate)"),
    (re.compile(r"\bmake_(unique|shared)\b"), "smart-pointer allocation"),
    (re.compile(r"\bDBG\s*\("), "DBG logging"),
    (re.compile(r"\b(Logger::|std::cout|std::cerr|printf|fprintf)\b"), "logging/IO"),
    (re.compile(r"\b(fopen|ifstream|ofstream|fstream)\b"), "file IO"),
    (re.compile(r"\bMessageManager::callAsync\b"), "callAsync (allocates)"),
    (re.compile(r"\bsendChangeMessage\b"), "change broadcast from RT context"),
    (re.compile(r"\b(sleep|usleep|nanosleep|wait_for|wait_until|condition_variable)\b"), "blocking wait"),
    (re.compile(r"\b(copyState|replaceState|getStateInformation|setStateInformation)\s*\("),
     "state ops (lock; message thread only)"),
]


def strip_comments(text: str) -> str:
    text = re.sub(r"//[^\n]*", "", text)
    return re.sub(r"/\*.*?\*/", "", text, flags=re.S)


def scan(path: str) -> list[str]:
    try:
        src = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return []
    findings = []
    for m in RT_FUNCS.finditer(src):
        brace = src.find("{", m.end())
        if brace == -1 or ";" in src[m.end():brace]:
            continue  # declaration, not definition
        depth, i = 1, brace + 1
        while i < len(src) and depth:
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
            i += 1
        body = strip_comments(src[brace:i])
        base_line = src[:brace].count("\n") + 1
        for pat, why in BANNED:
            for bm in pat.finditer(body):
                line = base_line + body[: bm.start()].count("\n")
                findings.append(f"{path}:{line} in {m.group(1)}(): {why}")
    return findings


def main() -> int:
    all_findings = []
    for path in sys.argv[1:]:
        if path.endswith((".cpp", ".h", ".hpp", ".cc", ".cxx")):
            all_findings.extend(scan(path))
    if all_findings:
        print("RT-SAFETY violations (standards/10-realtime-rules.md):", file=sys.stderr)
        for f in all_findings:
            print(f"  {f}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
