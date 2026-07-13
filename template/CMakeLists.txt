# gummy-berry-juce plugin template.
# Scaffold substitutions: GummyPlugin (target/product), gummyplugin (bundle id),
# Gbp1 (plugin code — unique 4 chars, first uppercase), IS_SYNTH/MIDI flags,
# and your own COMPANY_NAME / BUNDLE_ID prefix / PLUGIN_MANUFACTURER_CODE.
cmake_minimum_required(VERSION 3.25)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" GB_VERSION)
string(STRIP "${GB_VERSION}" GB_VERSION)

project(GummyPlugin VERSION ${GB_VERSION} LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(GB_ENABLE_CLAP "Build a CLAP target via clap-juce-extensions" OFF)
option(GB_WARNINGS_AS_ERRORS "Treat warnings as errors on project code" ON)
set(GB_JUCE_PATH "" CACHE PATH "Local JUCE checkout (skips FetchContent)")

# Universal binaries for release/CI; local dev builds native arch for speed.
if(DEFINED ENV{CI} AND APPLE)
    set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
endif()

include(FetchContent)

if(GB_JUCE_PATH)
    add_subdirectory(${GB_JUCE_PATH} ${CMAKE_BINARY_DIR}/JUCE)
else()
    FetchContent_Declare(JUCE
        GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
        GIT_TAG 8.0.4)
    FetchContent_MakeAvailable(JUCE)
endif()

# JUCE's frontend JS library is embedded with the UI; keep it in sync with the
# JUCE checkout at configure time.
if(GB_JUCE_PATH)
    set(GB_JUCE_JS_DIR "${GB_JUCE_PATH}/modules/juce_gui_extra/native/javascript")
else()
    set(GB_JUCE_JS_DIR "${juce_SOURCE_DIR}/modules/juce_gui_extra/native/javascript")
endif()
file(COPY "${GB_JUCE_JS_DIR}/index.js" "${GB_JUCE_JS_DIR}/check_native_interop.js"
     DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/ui/js/juce")

juce_add_plugin(GummyPlugin
    COMPANY_NAME "Marula Music"
    BUNDLE_ID com.marulamusic.gummyplugin
    PLUGIN_MANUFACTURER_CODE Mrla
    PLUGIN_CODE Gbp1
    FORMATS VST3 AU Standalone
    PRODUCT_NAME "GummyPlugin"
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    NEEDS_WEB_BROWSER TRUE
    NEEDS_WEBVIEW2 TRUE
    COPY_PLUGIN_AFTER_BUILD TRUE)

set(GB_SOURCES
    src/PluginProcessor.cpp
    src/PluginEditor.cpp)

set(GB_COMPILE_DEFS
    JUCE_WEB_BROWSER=1
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0
    $<$<PLATFORM_ID:Windows>:JUCE_USE_WIN_WEBVIEW2=1>
    $<$<PLATFORM_ID:Windows>:JUCE_USE_WIN_WEBVIEW2_WITH_STATIC_LINKING=1>)

if(GB_WARNINGS_AS_ERRORS)
    set(GB_WERROR $<IF:$<CXX_COMPILER_ID:MSVC>,/WX,-Werror>)
else()
    set(GB_WERROR "")
endif()

target_sources(GummyPlugin PRIVATE ${GB_SOURCES})
target_include_directories(GummyPlugin PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_compile_definitions(GummyPlugin PUBLIC ${GB_COMPILE_DEFS})
target_compile_options(GummyPlugin PRIVATE ${GB_WERROR})

# WebView UI assets, embedded as binary data.
juce_add_binary_data(GummyPluginUI
    HEADER_NAME GummyPluginUIData.h
    NAMESPACE GummyPluginUI
    SOURCES
        ui/index.html
        ui/css/main.css
        ui/js/main.js
        ui/js/juce/index.js
        ui/js/juce/check_native_interop.js)

target_link_libraries(GummyPlugin
    PRIVATE
        GummyPluginUI
        juce::juce_audio_utils
        juce::juce_dsp
        juce::juce_gui_extra
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags)

if(GB_ENABLE_CLAP)
    FetchContent_Declare(clap-juce-extensions
        GIT_REPOSITORY https://github.com/free-audio/clap-juce-extensions.git
        GIT_TAG main)
    FetchContent_MakeAvailable(clap-juce-extensions)
    clap_juce_extensions_plugin(TARGET GummyPlugin
        CLAP_ID "com.marulamusic.gummyplugin"
        CLAP_FEATURES audio-effect)
endif()

# ------------------------------------------------------------------ tests ----
FetchContent_Declare(Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.5.2)
FetchContent_MakeAvailable(Catch2)

# Console app so plugin sources compile with JUCE module defines; PluginEditor
# compiles in so createEditor() links.
juce_add_console_app(GummyPluginTests PRODUCT_NAME "GummyPluginTests"
    NEEDS_WEB_BROWSER TRUE
    NEEDS_WEBVIEW2 TRUE)
target_sources(GummyPluginTests PRIVATE
    tests/PluginBasicsTest.cpp
    ${GB_SOURCES})
target_include_directories(GummyPluginTests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_compile_definitions(GummyPluginTests PRIVATE ${GB_COMPILE_DEFS}
    JucePlugin_Name="GummyPlugin")   # console-app target lacks the plugin defines
target_compile_options(GummyPluginTests PRIVATE ${GB_WERROR})
target_link_libraries(GummyPluginTests PRIVATE
    GummyPluginUI
    juce::juce_audio_utils
    juce::juce_dsp
    juce::juce_gui_extra
    Catch2::Catch2WithMain
    juce::juce_recommended_config_flags)

enable_testing()
add_test(NAME GummyPluginTests COMMAND GummyPluginTests)
