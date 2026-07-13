#include "PluginEditor.h"
#include "GummyPluginUIData.h"
#include <cstdlib>

namespace
{
    constexpr int baseW = 480, baseH = 320;

    const char* const sliderParamIds[] = { "gain" };
    const char* const* toggleParamIds  = nullptr;   // none yet
    const char* const* comboParamIds   = nullptr;   // none yet
    constexpr size_t numToggles = 0, numCombos = 0;

    struct Asset { const char* path; const char* resource; const char* mime; };
    const Asset assets[] = {
        { "/",                                "index_html",              "text/html" },
        { "/index.html",                      "index_html",              "text/html" },
        { "/css/main.css",                    "main_css",                "text/css" },
        { "/js/main.js",                      "main_js",                 "text/javascript" },
        { "/js/juce/index.js",                "index_js",                "text/javascript" },
        { "/js/juce/check_native_interop.js", "check_native_interop_js", "text/javascript" },
    };

    const char* mimeForFile (const juce::String& name)
    {
        if (name.endsWith (".html"))  return "text/html";
        if (name.endsWith (".css"))   return "text/css";
        if (name.endsWith (".js"))    return "text/javascript";
        if (name.endsWith (".woff2")) return "font/woff2";
        if (name.endsWith (".svg"))   return "image/svg+xml";
        return "application/octet-stream";
    }
}

//==============================================================================
GummyPluginAudioProcessorEditor::GummyPluginAudioProcessorEditor (GummyPluginAudioProcessor& p)
    : AudioProcessorEditor (p), proc (p),
      webView ((createRelays(), makeOptions()))
{
    auto& apvts = proc.apvts();

    for (size_t i = 0; i < std::size (sliderParamIds); ++i)
        if (auto* param = apvts.getParameter (sliderParamIds[i]))
            sliderAttachments.push_back (
                std::make_unique<juce::WebSliderParameterAttachment> (*param, *sliderRelays[i], nullptr));

    for (size_t i = 0; i < numToggles; ++i)
        if (auto* param = apvts.getParameter (toggleParamIds[i]))
            toggleAttachments.push_back (
                std::make_unique<juce::WebToggleButtonParameterAttachment> (*param, *toggleRelays[i], nullptr));

    for (size_t i = 0; i < numCombos; ++i)
        if (auto* param = apvts.getParameter (comboParamIds[i]))
            comboAttachments.push_back (
                std::make_unique<juce::WebComboBoxParameterAttachment> (*param, *comboRelays[i], nullptr));

    addAndMakeVisible (webView);
    webView.goToURL (juce::WebBrowserComponent::getResourceProviderRoot());

    setResizable (true, true);
    setResizeLimits (baseW / 2, baseH / 2, baseW * 2, baseH * 2);
    if (auto* constrainer = getConstrainer())
        constrainer->setFixedAspectRatio ((double) baseW / baseH);
    setSize (baseW, baseH);
}

GummyPluginAudioProcessorEditor::~GummyPluginAudioProcessorEditor() = default;

void GummyPluginAudioProcessorEditor::resized()
{
    webView.setBounds (getLocalBounds());
}

//==============================================================================
void GummyPluginAudioProcessorEditor::createRelays()
{
    for (auto* id : sliderParamIds)
        sliderRelays.push_back (std::make_unique<juce::WebSliderRelay> (id));
    for (size_t i = 0; i < numToggles; ++i)
        toggleRelays.push_back (std::make_unique<juce::WebToggleButtonRelay> (toggleParamIds[i]));
    for (size_t i = 0; i < numCombos; ++i)
        comboRelays.push_back (std::make_unique<juce::WebComboBoxRelay> (comboParamIds[i]));
}

juce::WebBrowserComponent::Options GummyPluginAudioProcessorEditor::makeOptions()
{
    auto safeThis = juce::Component::SafePointer<GummyPluginAudioProcessorEditor> (this);

    auto options =
        juce::WebBrowserComponent::Options{}
           #if JUCE_WINDOWS
            .withBackend (juce::WebBrowserComponent::Options::Backend::webview2)
            .withWinWebView2Options (
                juce::WebBrowserComponent::Options::WinWebView2{}
                    .withUserDataFolder (juce::File::getSpecialLocation (juce::File::tempDirectory)))
           #endif
            .withNativeIntegrationEnabled()
            .withKeepPageLoadedWhenBrowserIsHidden()
            .withResourceProvider ([safeThis] (const auto& url)
                                   -> std::optional<juce::WebBrowserComponent::Resource>
            {
                if (safeThis == nullptr) return std::nullopt;
                return safeThis->getResource (url);
            },
            juce::String ("*")); // CORS header — required for ES module loading

    for (auto& relay : sliderRelays) options = options.withOptionsFrom (*relay);
    for (auto& relay : toggleRelays) options = options.withOptionsFrom (*relay);
    for (auto& relay : comboRelays)  options = options.withOptionsFrom (*relay);

    return options;
}

//==============================================================================
std::optional<juce::WebBrowserComponent::Resource>
GummyPluginAudioProcessorEditor::getResource (const juce::String& url) const
{
    // Dev hot-reload: serve from disk when GB_UI_DIR is set. The request path
    // is untrusted, so confine the resolved file to the chosen directory.
    if (const char* dir = std::getenv ("GB_UI_DIR"))
    {
        const juce::File base { juce::String (dir) };
        const auto rel = url == "/" ? juce::String ("index.html")
                                    : url.fromFirstOccurrenceOf ("/", false, false);
        auto file = base.getChildFile (rel);
        if (file.isAChildOf (base) && file.existsAsFile())
        {
            juce::MemoryBlock mb;
            file.loadFileAsData (mb);
            const auto* bytes = static_cast<const std::byte*> (mb.getData());
            return juce::WebBrowserComponent::Resource {
                std::vector<std::byte> (bytes, bytes + mb.getSize()),
                juce::String (mimeForFile (file.getFileName())) };
        }
    }

    for (const auto& asset : assets)
    {
        if (url != asset.path) continue;
        int size = 0;
        if (const auto* data = GummyPluginUI::getNamedResource (asset.resource, size))
        {
            const auto* bytes = reinterpret_cast<const std::byte*> (data);
            return juce::WebBrowserComponent::Resource {
                std::vector<std::byte> (bytes, bytes + static_cast<size_t> (size)),
                juce::String (asset.mime) };
        }
    }
    return std::nullopt;
}
