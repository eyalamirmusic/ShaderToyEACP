add_executable(Plasma Main.cpp)
target_link_libraries(Plasma PRIVATE shadertoy-runtime)

set(BUNDLE_ID "com.shadertoyeacp.plasma")

set_target_properties(Plasma PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "Plasma"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(Plasma)
set_default_target_setting(Plasma)
