cmake_minimum_required(VERSION 3.31)
project(ShaderToyEACP VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if (APPLE)
    enable_language(OBJCXX)
    set(CMAKE_XCODE_ATTRIBUTE_CLANG_LINK_OBJC_RUNTIME NO)
endif ()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake")

option(SHADERTOY_UNITY_BUILD "Compile ShaderToyEACP libraries as CMake unity builds" OFF)

# eacp supplies both the GPU module this project targets and the CMake helpers
# every target here is configured with (set_default_target_setting,
# eacp_set_gui_subsystem, add_ide_sources), so the fetch has to happen before
# the helpers are included rather than alongside the other dependencies.
find_package(Eacp REQUIRED)

list(APPEND CMAKE_MODULE_PATH "${eacp_SOURCE_DIR}/CMake")
include(TargetSetup)
include(ShadertoyTargets)

# eacp only runs this for itself when it is the top-level project, so a consumer
# has to call it or the Apple deployment target and bundle plist template are
# never set. It reads them out of *this* project's CMake directory, which is why
# macOSBundleInfo.plist.in is vendored here alongside CPM.
if (PROJECT_IS_TOP_LEVEL)
    eacp_default_setup()
endif ()

set(CMAKE_CXX_STANDARD 20)
add_subdirectory(Lib)

# The transpiler runs as a build step for the ports below, so it is built
# whether or not the examples are.
add_subdirectory(Tools)

option(SHADERTOY_ENABLE_EXAMPLES "Enable Examples for ShaderToyEACP" ${PROJECT_IS_TOP_LEVEL})

if (SHADERTOY_ENABLE_EXAMPLES)
    # Only the apps read it, and only one of them - the Gallery, which shows a
    # shader's GLSL beside the C++ it converted to. A build configured for the
    # transpiler and the scan alone should not be fetching tree-sitter, so the
    # fetch is here rather than beside eacp's.
    find_package(ECode REQUIRED)

    add_subdirectory(Apps)
endif ()

option(SHADERTOY_ENABLE_TESTS "Enable Tests for ShaderToyEACP" ${PROJECT_IS_TOP_LEVEL})

if (SHADERTOY_ENABLE_TESTS)
    enable_testing()
    add_subdirectory(Tests)
endif ()
