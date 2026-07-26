add_executable(Gallery Main.cpp)
target_link_libraries(Gallery PRIVATE shadertoy-runtime)

# The whole corpus, converted at build time. This is the one target that takes
# every shader rather than one, so a shader the transpiler is happy with but a
# C++ compiler is not fails the build here - which is the check the coverage
# report cannot make and the reason the list below is not filtered.
set(GALLERY_SHADERS
        Basis
        Channels
        Checker
        Compose
        Facets
        Fbm
        Gradient
        Kaleido
        Lattice
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

set(BUNDLE_ID "com.shadertoyeacp.gallery")

set_target_properties(Gallery PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "Gallery"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(Gallery)
set_default_target_setting(Gallery)
