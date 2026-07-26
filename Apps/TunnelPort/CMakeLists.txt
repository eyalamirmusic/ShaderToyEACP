add_executable(TunnelPort Main.cpp)
target_link_libraries(TunnelPort PRIVATE shadertoy-runtime)

shadertoy_add_port(TunnelPort GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Tunnel.glsl NAME Tunnel)

set(BUNDLE_ID "com.shadertoyeacp.tunnelport")

set_target_properties(TunnelPort PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "TunnelPort"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${BUNDLE_ID}
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID})

eacp_set_gui_subsystem(TunnelPort)
set_default_target_setting(TunnelPort)
