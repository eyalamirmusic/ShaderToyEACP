add_executable(PlasmaPort Main.cpp)
target_link_libraries(PlasmaPort PRIVATE shadertoy-runtime)

shadertoy_add_port(PlasmaPort GLSL Plasma.glsl NAME Plasma)

set(BUNDLE_ID "com.shadertoyeacp.plasmaport")

set_target_properties(PlasmaPort PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "PlasmaPort"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(PlasmaPort)
set_default_target_setting(PlasmaPort)
