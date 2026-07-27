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
        Leaving
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

# And the measured half: the corpus the coverage tables are measured over,
# fetched, scanned, and whatever converted and then compiled compiled in here
# too. No switch, because a gallery that shows some of the shaders depending on
# how the build directory was configured is a gallery nobody can trust the
# count of - and there were two ways to spell that mistake before this.
#
# Beside the committed list rather than instead of it, because the two are
# different claims. Every port above fails this build if it stops compiling,
# which is why each is worth holding by hand; most of the corpus below does not
# convert at all, so the same rule there would mean a build that never ran. The
# app says which half an entry came from.
shadertoy_add_measured_corpus(Gallery)

set(BUNDLE_ID "com.shadertoyeacp.gallery")

set_target_properties(Gallery PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "Gallery"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(Gallery)
set_default_target_setting(Gallery)
