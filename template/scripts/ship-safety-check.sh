#!/usr/bin/env bash
# gummy-berry ship-safety assertion (AUD-89 / 8.3).
#
# Safety here is primarily structural: the plugin's WebView UI entry point
# (ui/js/main.js) has no import of the dev-only @gummy-berry/studio or
# @gummy-berry/agent packages, so nothing pulls them into the esbuild bundle
# that juce_add_binary_data embeds into the shipped plugin (see AUD-88).
# This script is the regression trip-wire: if someone later adds such an
# import, it fails loudly and says why, instead of quietly shipping dev-only
# code (studio: full React tool surfaces; agent: a WS-connected page agent
# that patches the live DOM) inside a release plugin binary.
#
# Checks:
#   1. juce_add_binary_data's SOURCES list in CMakeLists.txt has <= 3 entries
#      (the AUD-88 baseline: ui/index.html, ui/dist/main.css, ui/dist/main.js).
#      A count above that is itself a signal the asset table grew back out,
#      independent of what's actually inside the new entries.
#   2. Neither the built UI bundle (ui/dist/main.js) nor the compiled plugin
#      artefacts (VST3/AU/Standalone, wherever juce_add_binary_data's byte
#      arrays end up linked in) contain literal identifiers that are unique
#      to @gummy-berry/studio or @gummy-berry/agent -- their package names and
#      a couple of distinctive exported symbols, chosen specifically because
#      they would not appear in this codebase by coincidence.
#
# Usage: scripts/ship-safety-check.sh [build-dir]
#   [build-dir] defaults to build-gate and must already contain a Release
#   build (see scripts/gate.sh, which runs this as GATE 5/5, after the build
#   stage). Running it before a build fails loudly rather than passing green
#   on nothing.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="${1:-build-gate}"
PROJECT_NAME="$(grep -m1 '^project(' CMakeLists.txt | sed -E 's/project\(([A-Za-z0-9_]+).*/\1/')"

# Identifiers unique enough to @gummy-berry/studio and @gummy-berry/agent that
# they cannot plausibly appear in this codebase except via an import of one of
# those packages (checked against their actual source: package.json "name"
# fields, and each package's most distinctive exported symbol).
FORBIDDEN=(
    '@gummy-berry/studio'
    '@gummy-berry/agent'
    'bootstrapPageAgent'
    'createPageAgent'
    'StudioShell'
)

echo "=== ship-safety 1/2: juce_add_binary_data SOURCES entry count ==="
SOURCES_COUNT="$(awk '
    /juce_add_binary_data\(/ { in_call = 1 }
    in_call && /^[ \t]*SOURCES[ \t]*$/ { in_sources = 1; next }
    in_sources {
        line = $0
        closing = (line ~ /\)/)
        gsub(/\)/, "", line)
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        if (line != "" && line !~ /^#/) count++
        if (closing) { in_sources = 0; in_call = 0 }
    }
    END { print count + 0 }
' CMakeLists.txt)"

echo "juce_add_binary_data SOURCES entries: ${SOURCES_COUNT}"
if [ "${SOURCES_COUNT}" -eq 0 ]; then
    echo "SHIP-SAFETY FAIL: could not find a juce_add_binary_data(... SOURCES ...) block in CMakeLists.txt (parser bug or the call was renamed/removed)." >&2
    exit 1
fi
if [ "${SOURCES_COUNT}" -gt 3 ]; then
    echo "SHIP-SAFETY FAIL: juce_add_binary_data has ${SOURCES_COUNT} SOURCES entries (max 3 allowed)." >&2
    echo "  AUD-88 set the baseline at 3 (ui/index.html, ui/dist/main.css, ui/dist/main.js)." >&2
    echo "  A larger asset table is itself a regression signal, independent of what's in it." >&2
    exit 1
fi

echo "=== ship-safety 2/2: scanning shipped artefacts for studio/agent symbols ==="
SCAN_TARGETS=()
[ -f "ui/dist/main.js" ] && SCAN_TARGETS+=("ui/dist/main.js")
[ -f "ui/dist/main.css" ] && SCAN_TARGETS+=("ui/dist/main.css")

for pat in "${PROJECT_NAME}.vst3" "${PROJECT_NAME}.component" "${PROJECT_NAME}.app" "${PROJECT_NAME}"; do
    while IFS= read -r -d '' f; do
        SCAN_TARGETS+=("$f")
    done < <(find "${BUILD_DIR}" -path '*Release*' -iname "${pat}" -print0 2>/dev/null)
done

if [ ${#SCAN_TARGETS[@]} -eq 0 ]; then
    echo "SHIP-SAFETY FAIL: no built artefacts found under '${BUILD_DIR}' (Release VST3/AU/Standalone, or ui/dist/main.js)." >&2
    echo "  Build the Release configuration first: cmake --build ${BUILD_DIR}." >&2
    exit 1
fi

echo "Scanning:"
printf '  - %s\n' "${SCAN_TARGETS[@]}"

fail=0
for needle in "${FORBIDDEN[@]}"; do
    for target in "${SCAN_TARGETS[@]}"; do
        # -r recurses into bundle directories (.vst3/.component/.app); -a treats
        # compiled binaries as text so the same grep works on both the raw JS
        # bundle and the Mach-O/resources inside a plugin bundle; -l keeps
        # output to one hit per matching file.
        if grep -rlaF -- "${needle}" "${target}" 2>/dev/null | grep -q .; then
            echo "SHIP-SAFETY FAIL: found forbidden symbol '${needle}' under ${target}" >&2
            fail=1
        fi
    done
done

if [ "${fail}" -ne 0 ]; then
    echo "" >&2
    echo "SHIP-SAFETY FAIL: dev-only @gummy-berry/studio or @gummy-berry/agent code" >&2
    echo "  leaked into the release build. Check ui/js/main.js (and anything it" >&2
    echo "  transitively imports) for an accidental import of either package --" >&2
    echo "  esbuild bundles whatever main.js imports into ui/dist/main.js, and" >&2
    echo "  juce_add_binary_data embeds that bundle verbatim into the plugin." >&2
    exit 1
fi

echo "=== ship-safety PASSED: no studio/agent symbols found, ${SOURCES_COUNT} binary-data entries ==="
