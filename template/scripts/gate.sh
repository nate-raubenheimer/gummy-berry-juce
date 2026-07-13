#!/usr/bin/env bash
# gummy-berry quality gate: build (-Werror) → clang-tidy → tests → pluginval 10.
# Blocking and sequential. A red gate means the task is NOT done.
# Usage: scripts/gate.sh  (from the project root; honors GB_JUCE_PATH env var)
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_NAME="$(grep -m1 '^project(' CMakeLists.txt | sed -E 's/project\(([A-Za-z0-9_]+).*/\1/')"
BUILD_DIR="build-gate"
JUCE_ARG=()
[ -n "${GB_JUCE_PATH:-}" ] && JUCE_ARG=(-DGB_JUCE_PATH="${GB_JUCE_PATH}")

missing=()
command -v cmake      >/dev/null || missing+=("cmake (brew install cmake)")
command -v clang-tidy >/dev/null || missing+=("clang-tidy (brew install llvm && add \$(brew --prefix llvm)/bin to PATH)")
command -v pluginval  >/dev/null || missing+=("pluginval (brew install --cask pluginval)")
if [ ${#missing[@]} -gt 0 ]; then
  echo "GATE: missing required tools — install them; the gate does not skip stages:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "=== GATE 1/4: configure + build (Release, warnings-as-errors) ==="
cmake -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release \
      -DGB_WARNINGS_AS_ERRORS=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      "${JUCE_ARG[@]}"
cmake --build "$BUILD_DIR" --parallel

echo "=== GATE 2/4: clang-tidy (project sources) ==="
find src -name '*.cpp' -print0 | xargs -0 clang-tidy -p "$BUILD_DIR" --quiet

echo "=== GATE 3/4: tests (CTest) ==="
ctest --test-dir "$BUILD_DIR" --output-on-failure

echo "=== GATE 4/4: pluginval --strictness-level 10 ==="
VST3="$BUILD_DIR/${PROJECT_NAME}_artefacts/Release/VST3/${PROJECT_NAME}.vst3"
if [ ! -d "$VST3" ]; then
  # PRODUCT_NAME may differ from the target name; take the first .vst3 found
  VST3="$(find "$BUILD_DIR" -name '*.vst3' -path '*Release*' -print -quit)"
fi
[ -n "$VST3" ] && [ -d "$VST3" ] || { echo "GATE: VST3 artefact not found" >&2; exit 1; }
pluginval --strictness-level 10 --validate "$VST3"

echo "=== GATE PASSED ==="
