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

# 8.2 (AUD-88): the WebView UI (ui/js/main.js + ui/css/main.css, which imports
# the JUCE frontend library copied above as a relative ES module) is bundled
# by esbuild (ui/build.mjs) into ui/dist/main.{js,css}. juce_add_binary_data
# (below) embeds file contents at CONFIGURE time, so the bundle must exist on
# disk before that call runs -- hence the synchronous npm install/build here.
# A custom command further below additionally reruns the bundler at BUILD
# time whenever ui/js or ui/css change, so `cmake --build` alone (no
# reconfigure) picks up UI edits.
find_program(NPM_EXECUTABLE npm)
if(NOT NPM_EXECUTABLE)
    message(FATAL_ERROR
        "GummyPlugin: npm not found on PATH. Node.js/npm is a required build "
        "dependency for the WebView UI bundle (ui/build.mjs, esbuild) -- "
        "install Node.js and reconfigure.")
endif()

execute_process(
    COMMAND ${NPM_EXECUTABLE} install
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ui
    RESULT_VARIABLE GB_UI_NPM_INSTALL_RESULT)
if(NOT GB_UI_NPM_INSTALL_RESULT EQUAL 0)
    message(FATAL_ERROR "GummyPlugin: `npm install` failed in ui/ (exit ${GB_UI_NPM_INSTALL_RESULT}).")
endif()

execute_process(
    COMMAND ${NPM_EXECUTABLE} run build
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ui
    RESULT_VARIABLE GB_UI_NPM_BUILD_RESULT)
if(NOT GB_UI_NPM_BUILD_RESULT EQUAL 0)
    message(FATAL_ERROR "GummyPlugin: `npm run build` failed in ui/ (exit ${GB_UI_NPM_BUILD_RESULT}).")
endif()

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

# Rebuild the UI bundle at BUILD time (not just configure time) whenever its
# inputs change, so `cmake --build` alone picks up UI edits without a
# reconfigure. juce_add_binary_data's own custom command (JUCE's
# JUCEUtils.cmake) already DEPENDS on ui/dist/main.{js,css} and reruns
# juceaide whenever their mtimes change -- this command is what keeps those
# mtimes honest.
file(GLOB_RECURSE GB_UI_SOURCE_FILES CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/js/*.js
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/css/*.css)

add_custom_command(
    OUTPUT
        ${CMAKE_CURRENT_SOURCE_DIR}/ui/dist/main.js
        ${CMAKE_CURRENT_SOURCE_DIR}/ui/dist/main.css
    COMMAND ${NPM_EXECUTABLE} run build
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ui
    DEPENDS ${GB_UI_SOURCE_FILES} ${CMAKE_CURRENT_SOURCE_DIR}/ui/build.mjs
    COMMENT "GummyPlugin: bundling WebView UI (esbuild)"
    VERBATIM)

add_custom_target(GummyPluginUIBundle
    DEPENDS
        ${CMAKE_CURRENT_SOURCE_DIR}/ui/dist/main.js
        ${CMAKE_CURRENT_SOURCE_DIR}/ui/dist/main.css)

# WebView UI assets, embedded as binary data.
juce_add_binary_data(GummyPluginUI
    HEADER_NAME GummyPluginUIData.h
    NAMESPACE GummyPluginUI
    SOURCES
        ui/index.html
        ui/dist/main.css
        ui/dist/main.js)

add_dependencies(GummyPluginUI GummyPluginUIBundle)

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
