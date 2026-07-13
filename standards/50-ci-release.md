# CI & Release

## CI matrix (GitHub Actions)

| Job | Runner | Purpose |
|---|---|---|
| `mac` | `macos-latest` | Build VST3+AU+Standalone (Release), run CTest, run pluginval 10 |
| `windows` | `windows-latest` | Build VST3 (Release) — must stay green; not the daily loop |
| `sanitize` | `macos-latest` | Debug build of the test target with ASan+UBSan; CTest |

Rules of thumb (learned from the field):

- `timeout-minutes` on **every** job — debug assertion hangs are the classic CI black hole; macOS minutes cost 10x.
- Cache with ccache/sccache; JUCE 8 supports sccache well.
- Universal binaries for release: `CMAKE_OSX_ARCHITECTURES="arm64;x86_64"` (CI/release only — local dev builds native arch for speed).
- pluginval invocation: `pluginval --strictness-level 10 --validate <plugin>` — nonzero exit fails the job.
- Budget ~10% ongoing maintenance; pipelines rot.

## macOS signing & notarization (release builds)

1. **Developer ID Application** cert signs bundles (VST3/AU/app); **Developer ID Installer** signs the `.pkg`.
2. Sign: `codesign --force -s "Developer ID Application: …" --deep --strict --options=runtime --timestamp <bundle>`.
3. Notarize the **outermost container only**: `xcrun notarytool submit <pkg> --wait`, then `xcrun stapler staple`.
4. Prefer `.pkg` installers (plugins install to system folders; drag-and-drop doesn't fit).
5. Secrets needed in CI: base64 `.p12` + password, team ID, Apple ID, app-specific password.

## Windows signing

Azure Trusted Signing (Pamplejuce's current approach) or an EV cert. Defer until distributing Windows builds; keep the CI build green meanwhile.

## Versioning

- `VERSION` file at repo root is the single source of truth; CMake reads it; installers and `JucePlugin_Version` derive from it.
- Parameter layout changes after a release require new `ParameterID` version hints ([40-style-modern-cpp.md](40-style-modern-cpp.md)).

## Release checklist

1. Gate passes locally (`scripts/gate.sh`).
2. CI green on all jobs.
3. Version bumped, CHANGELOG entry written.
4. Signed + notarized artifacts produced from CI, never from a laptop.
5. Manual smoke test in at least one real host (Live/Logic) — pluginval is necessary, not sufficient.
