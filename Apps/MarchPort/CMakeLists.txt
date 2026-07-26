add_executable(MarchPort Main.cpp)
target_link_libraries(MarchPort PRIVATE shadertoy-runtime)

shadertoy_add_port(MarchPort GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Raymarch.glsl NAME Raymarch)

set(BUNDLE_ID "com.shadertoyeacp.marchport")

set_target_properties(MarchPort PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "MarchPort"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(MarchPort)
set_default_target_setting(MarchPort)
