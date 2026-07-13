// Seed test suite: the spec-test matrix every gummy-berry plugin starts from.
// Extend per standards/30-testing.md — every DSP unit ships with its own tests.
#include <catch2/catch_approx.hpp>
#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>
#include "PluginProcessor.h"

namespace
{
    void prepareAndProcess (GummyPluginAudioProcessor& proc,
                            juce::AudioBuffer<float>& buffer,
                            double sampleRate, int blockSize)
    {
        proc.setPlayConfigDetails (2, 2, sampleRate, blockSize);
        proc.prepareToPlay (sampleRate, blockSize);
        juce::MidiBuffer midi;
        proc.processBlock (buffer, midi);
    }

    bool allFinite (const juce::AudioBuffer<float>& buffer)
    {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
            for (int i = 0; i < buffer.getNumSamples(); ++i)
                if (! std::isfinite (buffer.getSample (ch, i)))
                    return false;
        return true;
    }
}

TEST_CASE ("Parameter layout matches the contract", "[parameters]")
{
    GummyPluginAudioProcessor proc;
    auto* gain = proc.apvts().getParameter ("gain");
    REQUIRE (gain != nullptr);
    REQUIRE (proc.apvts().getRawParameterValue ("gain") != nullptr);
}

TEST_CASE ("Silence in, silence out across SR/block matrix", "[dsp]")
{
    const auto sampleRate = GENERATE (44100.0, 48000.0, 96000.0);
    const auto blockSize  = GENERATE (1, 16, 333, 4096);

    GummyPluginAudioProcessor proc;
    juce::AudioBuffer<float> buffer (2, blockSize);
    buffer.clear();
    prepareAndProcess (proc, buffer, sampleRate, blockSize);

    REQUIRE (allFinite (buffer));
    REQUIRE (buffer.getMagnitude (0, blockSize) == 0.0f);
}

TEST_CASE ("No NaN/inf for full-scale noise, including zero-length blocks", "[dsp]")
{
    const auto blockSize = GENERATE (0, 1, 512);

    GummyPluginAudioProcessor proc;
    juce::AudioBuffer<float> buffer (2, juce::jmax (1, blockSize));
    buffer.setSize (2, blockSize, false, true, true);

    juce::Random rng (42);
    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        for (int i = 0; i < buffer.getNumSamples(); ++i)
            buffer.setSample (ch, i, rng.nextFloat() * 2.0f - 1.0f);

    prepareAndProcess (proc, buffer, 48000.0, juce::jmax (1, blockSize));
    REQUIRE (allFinite (buffer));
}

TEST_CASE ("State save/load round-trip preserves parameters", "[state]")
{
    GummyPluginAudioProcessor procA;
    auto* gain = procA.apvts().getParameter ("gain");
    REQUIRE (gain != nullptr);
    gain->setValueNotifyingHost (0.75f);

    juce::MemoryBlock blob;
    procA.getStateInformation (blob);

    GummyPluginAudioProcessor procB;
    procB.setStateInformation (blob.getData(), static_cast<int> (blob.getSize()));

    REQUIRE (procB.apvts().getParameter ("gain")->getValue()
             == Catch::Approx (0.75f).margin (1.0e-6));
}
