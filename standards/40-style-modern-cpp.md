# Style & Modern C++

Project standard: **C++20** (C++23 opt-in per project once minimum macOS deployment target allows its library features).

## C++20 subset table

| Freely use | RT-forbidden (fine elsewhere) | Avoid everywhere |
|---|---|---|
| `constexpr`/`consteval` DSP tables & coefficients | `std::function` | `std::any` |
| `std::span` for buffer views | `std::shared_ptr` copies | Raw owning pointers |
| Concepts for DSP processor templates | `std::variant` visitation that allocates | `juce::ScopedPointer` (deprecated) |
| `if constexpr`, structured bindings | Exceptions | Macros (except JUCE's required ones) |
| `std::clamp`, `std::lerp`, `<numbers>` | Coroutines | `using namespace` in headers |
| Designated initializers | Ranges pipelines (allocation risk) | RTTI-dependent designs |
| `[[nodiscard]]`, `noexcept` on DSP | | |

## Ownership rules

- RAII everywhere. `std::unique_ptr` is the default owner; raw pointers/references mean *non-owning observation only*.
- `juce::Component::SafePointer` for components that may die; `ReferenceCountedObjectPtr` where the release-pool pattern needs it.
- `JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR` on every Component and Processor class.
- Nothing is ever destroyed on the audio thread.

## JUCE vs std idioms

| Prefer | Over | Except |
|---|---|---|
| `std::unique_ptr` | `juce::ScopedPointer` | — |
| `std::atomic` | `juce::Atomic` | — |
| `std::mutex` (non-RT) | `juce::CriticalSection` | when a JUCE API requires it |
| `std::numbers::pi` | `juce::MathConstants` | inside heavily-JUCE code, consistency wins |
| `juce::String` | `std::string` | **at JUCE API boundaries** — don't fight the framework |

## Style mechanics

- `.clang-format` (shipped in template) is law — applied automatically by hook/pre-commit; never hand-format.
- `.clang-tidy` (shipped): `bugprone-*, performance-*, modernize-*, readability-*, cppcoreguidelines-*` with JUCE-macro exclusions. Clean tidy is a gate requirement.
- `jassert` liberally for invariants (debug-only, RT-safe in practice); never `assert`.
- Naming follows JUCE conventions: `camelCase` methods/variables, `PascalCase` types, no `m_` prefixes.
- Comments state constraints the code can't express (thread ownership, units, ranges) — not narration.
- Every class that touches two threads documents which thread owns which member.

## Parameter conventions

- IDs are `snake_case`, stable forever once shipped, versioned: `ParameterID { "filter_cutoff", 1 }`.
- Ranges use real-world units with proper skew (`NormalisableRange` with skew for frequency, dB for gain).
- The parameter spec contract (`docs/contracts/parameters.md`) is the single source of truth — code, UI, and presets all derive from it.
