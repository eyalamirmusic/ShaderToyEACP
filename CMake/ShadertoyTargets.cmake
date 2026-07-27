function(shadertoy_enable_unity_build target)
    if (SHADERTOY_UNITY_BUILD)
        set_target_properties(${target} PROPERTIES UNITY_BUILD ON)
    endif ()
endfunction()

# Converts a Shadertoy GLSL file into a generated header at build time and puts
# it on the target's include path, so an app consumes a .glsl the way it would
# any other source file:
#
#   shadertoy_add_port(PlasmaPort GLSL Plasma.glsl NAME Plasma)
#   ...
#   Shadertoy::Ports::Plasma shader;
#
# The conversion fails the build when the shader needs something the EDSL cannot
# express yet, which is deliberate: a port that quietly drew the wrong thing
# would be worse than one that does not build. Pass FORCE to generate anyway
# while a gap is being worked on.
function(shadertoy_add_port target)
    cmake_parse_arguments(ARG "FORCE" "GLSL;NAME" "" ${ARGN})

    get_filename_component(source "${ARG_GLSL}" ABSOLUTE)
    set(directory "${CMAKE_CURRENT_BINARY_DIR}/${target}-ports")
    set(generated "${directory}/${ARG_NAME}.h")

    set(force_flag "")
    if (ARG_FORCE)
        set(force_flag "--force")
    endif ()

    add_custom_command(
            OUTPUT "${generated}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${directory}"
            COMMAND shadertoy-transpile "${source}"
                    -o "${generated}" --name "${ARG_NAME}" ${force_flag}
            DEPENDS shadertoy-transpile "${source}"
            COMMENT "Transpiling ${ARG_NAME} from ${ARG_GLSL}"
            VERBATIM)

    # Listed as a source so the custom command is scheduled, but never compiled
    # on its own - it is a header the target's own sources include.
    set_source_files_properties("${generated}" PROPERTIES
            GENERATED TRUE HEADER_FILE_ONLY TRUE)

    target_sources(${target} PRIVATE "${generated}")
    target_include_directories(${target} PRIVATE "${directory}")
endfunction()

# The whole of "Measure a corpus" as a build step: scan the shaders the coverage
# tables are measured over, register what survived, and put the registration on
# the target's include path.
#
#   shadertoy_add_measured_corpus(Gallery)
#
# What it adds is measured rather than guaranteed, which is why it is a
# different function from the one above: a port added by shadertoy_add_port
# fails the build if it stops compiling, and a corpus most of which does not
# convert cannot keep that rule.
#
# It does not fetch. The corpus is committed, so a clone has every shader this
# measures before it has a build directory - which is the only version of this
# that cannot quietly show 28 shaders while claiming 204, since there is no
# step left to have silently not happened. Growing the corpus past what is
# committed is `shadertoy-fetch`, run by hand; see the corpus-fetch target.
#
# Scanning stays per build directory, because what converts and then compiles is
# a fact about this compiler and these flags, and re-runs whenever the shaders or
# the transpiler being measured change.
function(shadertoy_add_measured_corpus target)
    set(shaders "${CMAKE_SOURCE_DIR}/Corpus/External")
    set(registered "${CMAKE_BINARY_DIR}/MeasuredCorpus")

    # The shaders themselves are the dependency: adding one to the corpus is
    # what should re-measure it, and CONFIGURE_DEPENDS is what notices.
    file(GLOB corpus CONFIGURE_DEPENDS "${shaders}/*.glsl")

    add_custom_command(
            OUTPUT "${registered}/ExternalCorpus.h"
            COMMAND shadertoy-scan "${shaders}"
                    --out "${registered}"
                    --register "${registered}/Survivors.cmake"
            DEPENDS shadertoy-scan ${corpus}
            COMMENT "Scanning the measured corpus, and registering what compiles"
            VERBATIM
            USES_TERMINAL)

    set_source_files_properties("${registered}/ExternalCorpus.h" PROPERTIES
            GENERATED TRUE HEADER_FILE_ONLY TRUE)

    target_sources(${target} PRIVATE "${registered}/ExternalCorpus.h")
    target_include_directories(${target} PRIVATE "${registered}")
endfunction()
