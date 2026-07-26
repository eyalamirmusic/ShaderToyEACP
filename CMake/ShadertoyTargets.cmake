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
