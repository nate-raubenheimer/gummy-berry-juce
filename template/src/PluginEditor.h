#pragma once
#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_gui_extra/juce_gui_extra.h>
#include <memory>
#include <optional>
#include <vector>
#include "PluginProcessor.h"

// WebView editor: the UI under ui/, embedded as binary data and served through
// the WebBrowserComponent resource provider. Every APVTS parameter is bridged
// to a JS control via a relay + parameter attachment. Add new parameter ids to
// the arrays in PluginEditor.cpp — nothing else changes.
class GummyPluginAudioProcessorEditor : public juce::AudioProcessorEditor
{
public:
    explicit GummyPluginAudioProcessorEditor (GummyPluginAudioProcessor&);
    ~GummyPluginAudioProcessorEditor() override;

    void resized() override;

private:
    void createRelays();
    juce::WebBrowserComponent::Options makeOptions();
    std::optional<juce::WebBrowserComponent::Resource> getResource (const juce::String& url) const;

    GummyPluginAudioProcessor& proc;

    std::vector<std::unique_ptr<juce::WebSliderRelay>>       sliderRelays;
    std::vector<std::unique_ptr<juce::WebToggleButtonRelay>> toggleRelays;
    std::vector<std::unique_ptr<juce::WebComboBoxRelay>>     comboRelays;

    std::vector<std::unique_ptr<juce::WebSliderParameterAttachment>>       sliderAttachments;
    std::vector<std::unique_ptr<juce::WebToggleButtonParameterAttachment>> toggleAttachments;
    std::vector<std::unique_ptr<juce::WebComboBoxParameterAttachment>>     comboAttachments;

    // Declared last: its ctor runs makeOptions(), which reads the relays above.
    juce::WebBrowserComponent webView;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (GummyPluginAudioProcessorEditor)
};
