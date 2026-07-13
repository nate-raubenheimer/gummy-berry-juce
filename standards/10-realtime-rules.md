# Real-Time Rules — Non-Negotiable

> Cardinal rule (Ross Bencina): **"If you don't know how long it will take, don't do it."**
> The audio callback has a hard deadline every few milliseconds. Miss it once and the user hears a glitch. There is no retry.

## Never on the audio thread

1. **No memory allocation or deallocation.** No `new`/`delete`/`malloc`/`free` — including *hidden* allocation:
   - `juce::String` construction or concatenation
   - `std::vector`/`std::map` growth (`push_back`, `resize`, `insert`, `operator[]` on maps)
   - `std::function` construction or assignment (lambda captures allocate)
   - `juce::ValueTree` operations
   - `std::shared_ptr` copies (refcount is fine; destruction on audio thread can free — banned)
2. **No locks.** No `std::mutex`, `juce::CriticalSection`, `ScopedLock`, condition variables, semaphores. A lock held by a lower-priority thread causes priority inversion → glitch. Try-locks are permitted only in the "try and skip" pattern (fail → use last known state).
3. **No I/O of any kind.** No files, network, MIDI device queries, `DBG` in release paths, `Logger`, `std::cout`.
4. **No unbounded syscalls.** No `sleep`, no thread creation, no ObjC messaging on the hot path.
5. **No exceptions thrown across the callback boundary.** DSP code is `noexcept` in spirit; use `jassert` for invariants.
6. **No calling code you don't trust** to obey all of the above (check third-party DSP libs before use).

## Required patterns (the approved toolbox)

### Every processBlock starts like this

```cpp
void processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi) override
{
    juce::ScopedNoDenormals noDenormals;                    // FTZ/DAZ — always
    const auto totalIn  = getTotalNumInputChannels();
    const auto totalOut = getTotalNumOutputChannels();
    for (auto ch = totalIn; ch < totalOut; ++ch)            // clear unused outputs — always
        buffer.clear (ch, 0, buffer.getNumSamples());
    // Never assume block size (may be 0, 1, or huge) or channel count.
```

### Parameter reads (APVTS)

```cpp
// Constructor — cache once:
gainParam = apvts.getRawParameterValue ("gain");            // std::atomic<float>*
// processBlock — load per block, smooth before applying:
gainSmoothed.setTargetValue (gainParam->load());
```

- All parameters live in **one** `AudioProcessorValueTreeState`, constructed with versioned `ParameterID { "gain", 1 }` (version hints are required for AU compatibility when parameters are added later).
- Audible parameters are smoothed (`juce::SmoothedValue` / `LinearSmoothedValue`) — zipper noise is a defect. Reset smoothers in `prepareToPlay`.
- `APVTS::Listener::parameterChanged` may fire on **any** thread: set an atomic flag, do the work elsewhere.
- State save/load via `copyState()`/`replaceState()` — message thread only (they lock).

### Audio → GUI (metering, analysis)

Audio thread **writes** to `std::atomic<float>` or an SPSC FIFO; GUI **polls** on a `juce::Timer` (30–60 Hz). Never send messages, never `MessageManager::callAsync` (allocates), never notify from audio.

```cpp
static_assert (std::atomic<float>::is_always_lock_free);
levelAtomic.store (rms, std::memory_order_relaxed);         // audio thread
// Timer callback (GUI): meter.setLevel (levelAtomic.load (std::memory_order_relaxed));
```

### GUI/Background → Audio (streams, events)

SPSC lock-free FIFO: `juce::AbstractFifo`, `chowdsp` FIFOs, or `moodycamel::ReaderWriterQueue`. One producer, one consumer, fixed capacity allocated in `prepareToPlay`.

### Big object handover (IR, wavetable, sample)

Release-pool pattern: build the new object on a **background thread**, publish with an atomic pointer exchange, and destroy the old object on the non-RT side.

```cpp
auto newTable = std::make_shared<Wavetable> (...);          // background thread
std::atomic_store (&activeTable, newTable);                 // publish
// audio thread: auto table = std::atomic_load (&activeTable);  (copy held for the block only —
// pool retains a reference so the audio thread never runs a destructor)
```

Libraries that implement these correctly: **farbot** (`RealtimeObject`), **crill** (`progressive_backoff_wait`). Prefer them over hand-rolling.

### prepareToPlay / releaseResources

- ALL allocation happens in `prepareToPlay`: buffers sized for `maximumExpectedSamplesPerBlock`, FIFOs, oversampling, smoothers reset.
- Handle sample-rate changes here only. Report latency via `setLatencySamples()` whenever oversampling/lookahead adds any.

## Verification

- CI runs **RealtimeSanitizer** (`-fsanitize=realtime`, LLVM 20+) with `[[clang::nonblocking]]` on `processBlock` where toolchain allows.
- Every edit to audio-thread files triggers the banned-symbol scan ([00-overview.md](00-overview.md)).
- The code-reviewer agent checks RT-safety semantically (things grep can't see: indirect allocation, lock inversion, wrong memory ordering).
