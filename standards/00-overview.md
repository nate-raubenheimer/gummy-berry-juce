# Standards Overview — The Three-Thread Model

Every line of plugin code runs on one of three threads. **Before writing any code, decide which thread it runs on** — that decision determines which rules apply.

| Thread | Entry points | Rules |
|---|---|---|
| **Audio (real-time)** | `processBlock`, anything it calls, `parameterChanged` (may fire here) | [10-realtime-rules.md](10-realtime-rules.md) — the non-negotiables. No allocation, no locks, no I/O. |
| **Message (GUI)** | Component paint/resized/callbacks, timers, `getStateInformation`/`setStateInformation`, WebView bridge handlers | May allocate and lock, must never block audio. Talk to audio thread only via atomics/FIFOs. |
| **Background (worker)** | `juce::Thread`, `ThreadPool`, async loaders | Free-for-all internally; hand results to audio thread via atomic pointer exchange, never directly. |

## Decision table

| You are writing... | Thread | Key constraints |
|---|---|---|
| DSP processing | Audio | RT rules; smooth parameters; `ScopedNoDenormals` |
| Parameter read in DSP | Audio | Cached `std::atomic<float>*` from `getRawParameterValue`, loaded per block |
| Metering / visualization data | Audio → Message | Audio writes atomic/FIFO; GUI polls on `juce::Timer`. Never push from audio. |
| Preset/state save-load | Message | `copyState()`/`replaceState()` only (they lock — message thread only) |
| Sample/IR/wavetable loading | Background → Audio | Allocate on background thread; swap in via atomic pointer; free old on non-RT thread (release pool) |
| UI ↔ parameter binding | Message | WebView relay / Attachment classes only — no manual listener spaghetti |

## Banned symbols on the audio thread (grep list)

These are mechanically scanned by `rt-safety-check` on every edit to audio-thread files:

```text
new  delete  malloc  calloc  realloc  free
std::mutex  std::lock_guard  std::unique_lock  std::scoped_lock  CriticalSection  ScopedLock
juce::String(   String::  std::string(  std::vector<...>.push_back/resize/reserve (growth)
std::function (construction/assignment)   std::shared_ptr (copy)
DBG(  Logger::  std::cout  printf  fopen  ifstream  ofstream
MessageManager::callAsync  sendChangeMessage  AsyncUpdater construction
getStateInformation  setStateInformation  copyState  replaceState
sleep  wait(  notify(  condition_variable
```

A match is not automatically a violation (comments, dead paths) — but it blocks until a human or reviewer explicitly clears it.

## File map

- [10-realtime-rules.md](10-realtime-rules.md) — audio-thread non-negotiables + approved patterns
- [20-cmake-structure.md](20-cmake-structure.md) — project layout, CMake conventions, formats
- [30-testing.md](30-testing.md) — testing doctrine, DSP spec tests, pluginval, sanitizers
- [40-style-modern-cpp.md](40-style-modern-cpp.md) — C++20 subset, JUCE-vs-std idioms, formatting
- [50-ci-release.md](50-ci-release.md) — CI matrix, signing, notarization, packaging
