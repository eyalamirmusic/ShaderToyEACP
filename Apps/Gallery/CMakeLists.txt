add_executable(Gallery Main.cpp)
target_link_libraries(Gallery PRIVATE shadertoy-runtime)

# The whole corpus, converted at build time. This is the one target that takes
# every shader rather than one, so a shader the transpiler is happy with but a
# C++ compiler is not fails the build here - which is the check the coverage
# report cannot make and the reason the list below is not filtered.
set(GALLERY_SHADERS
        Basis
        Blanks
        Channels
        Checker
        Compose
        Facets
        Fbm
        Gradient
        Kaleido
        Lattice
        Literals
        Macros
        Mandelbrot
        Palette
        Raymarch
        Surface
        TrailBuffer
        TrailImage
        Tunnel
        Voronoi)

foreach (shader IN LISTS GALLERY_SHADERS)
    shadertoy_add_port(Gallery
            GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/${shader}.glsl
            NAME ${shader})
endforeach ()

# The one that does not live in Corpus/: the shader both Plasma and PlasmaPort
# draw, which is what the hand port is compared against.
shadertoy_add_port(Gallery
        GLSL ${CMAKE_CURRENT_LIST_DIR}/../PlasmaPort/Plasma.glsl
        NAME Plasma)

# Real Shadertoys, by people who are not us - see Corpus/Imported/README.md for
# where they came from and why these are the ones that could be committed. They
# are named after their ids, which is what the site names them, prefixed because
# a C++ struct cannot start with a digit.
set(GALLERY_IMPORTED
        3l23RK
        4ssSRl
        7d23DR
        csscRl
        ctdfzN
        dldyWN
        ftVXRc
        sdVyWt)

foreach (shader IN LISTS GALLERY_IMPORTED)
    shadertoy_add_port(Gallery
            GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Imported/${shader}.glsl
            NAME S${shader})
endforeach ()

# The measured half, off by default. -DSHADERTOY_EXTERNAL_CORPUS=<dir> points
# at the directory shadertoy-scan left its generated headers in, and whatever
# converted and then compiled there is added beside the list above:
#
#   shadertoy-fetch --dataset
#   shadertoy-scan Corpus/External --out scan --register scan/Survivors.cmake
#   cmake -B build -DSHADERTOY_EXTERNAL_CORPUS=$PWD/scan
#
# Beside the committed list rather than instead of it, because the two mean
# different things and only one of them can keep the rule that makes it worth
# having. Every port above fails this build if it stops compiling, which is why
# each is worth holding by hand; most of an external corpus does not convert at
# all, so a build that insisted on one would never run.
if (SHADERTOY_EXTERNAL_CORPUS)
    set(external_table "${SHADERTOY_EXTERNAL_CORPUS}/ExternalCorpus.h")

    if (NOT EXISTS "${external_table}")
        message(FATAL_ERROR
                "SHADERTOY_EXTERNAL_CORPUS is ${SHADERTOY_EXTERNAL_CORPUS}, "
                "which holds no ExternalCorpus.h. That file is what registers "
                "the survivors, and shadertoy-scan --register writes it:\n"
                "  shadertoy-scan <corpus> --out ${SHADERTOY_EXTERNAL_CORPUS} "
                "--register <file>.cmake")
    endif ()

    # The table names the headers beside it, so the directory is the whole of
    # the include path and the one #include reaches all of them. The CMake list
    # --register writes is for a target that wants the names; this one only
    # wants them compiled in, and the X-macro is already that.
    target_include_directories(Gallery PRIVATE "${SHADERTOY_EXTERNAL_CORPUS}")

    message(STATUS "Gallery: adding the external corpus in "
            "${SHADERTOY_EXTERNAL_CORPUS}")
endif ()

set(BUNDLE_ID "com.shadertoyeacp.gallery")

set_target_properties(Gallery PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "Gallery"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(Gallery)
set_default_target_setting(Gallery)
