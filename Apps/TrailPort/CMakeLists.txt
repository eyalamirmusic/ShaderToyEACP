add_executable(TrailPort Main.cpp)
target_link_libraries(TrailPort PRIVATE shadertoy-runtime)

# Two .glsl files, two ports, one app: which is what a multi-buffer page is.
shadertoy_add_port(TrailPort GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/TrailBuffer.glsl NAME TrailBuffer)
shadertoy_add_port(TrailPort GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/TrailImage.glsl NAME TrailImage)

set(BUNDLE_ID "com.shadertoyeacp.trailport")

set_target_properties(TrailPort PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "TrailPort"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(TrailPort)
set_default_target_setting(TrailPort)
