#include "PluginProcessor.h"
#include "PluginEditor.h"

namespace
{
    constexpr auto gainParamId = "gain";
    constexpr float gainSmoothingSeconds = 0.02f;
}

GummyPluginAudioProcessor::GummyPluginAudioProcessor()
    : AudioProcessor (BusesProperties()
                          .withInput ("Input", juce::AudioChannelSet::stereo(), true)
                          .withOutput ("Output", juce::AudioChannelSet::stereo(), true)),
      state (*this, nullptr, "PARAMETERS", createParameterLayout())
{
    gainParam = state.getRawParameterValue (gainParamId);
    jassert (gainParam != nullptr);
}

juce::AudioProcessorValueTreeState::ParameterLayout
GummyPluginAudioProcessor::createParameterLayout()
{
    juce::AudioProcessorValueTreeState::ParameterLayout layout;

    layout.add (std::make_unique<juce::AudioParameterFloat> (
        juce::ParameterID { gainParamId, 1 },
        "Gain",
        juce::NormalisableRange<float> (-60.0f, 12.0f, 0.0f, 2.5f),
        0.0f,
        juce::AudioParameterFloatAttributes{}.withLabel ("dB")));

    return layout;
}

void GummyPluginAudioProcessor::prepareToPlay (double sampleRate, int)
{
    gainSmoothed.reset (sampleRate, gainSmoothingSeconds);
    gainSmoothed.setCurrentAndTargetValue (
        juce::Decibels::decibelsToGain (gainParam->load()));
}

bool GummyPluginAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    return layouts.getMainOutputChannelSet() == juce::AudioChannelSet::stereo()
        && layouts.getMainInputChannelSet() == layouts.getMainOutputChannelSet();
}

void GummyPluginAudioProcessor::processBlock (juce::AudioBuffer<float>& buffer,
                                              juce::MidiBuffer&)
{
    juce::ScopedNoDenormals noDenormals;

    const auto totalIn  = getTotalNumInputChannels();
    const auto totalOut = getTotalNumOutputChannels();
    for (auto ch = totalIn; ch < totalOut; ++ch)
        buffer.clear (ch, 0, buffer.getNumSamples());

    gainSmoothed.setTargetValue (juce::Decibels::decibelsToGain (gainParam->load()));

    const auto numSamples  = buffer.getNumSamples();
    const auto numChannels = buffer.getNumChannels();

    for (int i = 0; i < numSamples; ++i)
    {
        const auto gain = gainSmoothed.getNextValue();
        for (int ch = 0; ch < numChannels; ++ch)
            buffer.getWritePointer (ch)[i] *= gain;
    }
}

juce::AudioProcessorEditor* GummyPluginAudioProcessor::createEditor()
{
    return new GummyPluginAudioProcessorEditor (*this);
}

void GummyPluginAudioProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    if (auto xml = state.copyState().createXml())
        copyXmlToBinary (*xml, destData);
}

void GummyPluginAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    if (auto xml = getXmlFromBinary (data, sizeInBytes))
        if (xml->hasTagName (state.state.getType()))
            state.replaceState (juce::ValueTree::fromXml (*xml));
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new GummyPluginAudioProcessor();
}
