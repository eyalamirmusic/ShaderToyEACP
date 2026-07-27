include(CPM)

# The code viewer the Gallery shows a shader's two texts in - the Shadertoy GLSL
# it came from and the C++ the transpiler made of it. ECode::Editor is one
# document in a GPUView and nothing around it; ECode::Syntax is the tree-sitter
# grammar behind it, linked separately because the editor does not depend on it.
#
# ECode fetches eacp itself, under the same CPM name this project already used,
# so the package is deduplicated and both see one checkout - including the one
# pointed at by -DCPM_eacp_SOURCE. Which is why find_package(Eacp) has to come
# first: whichever call CPM sees first is the one whose OPTIONS take effect.
CPMAddPackage(
        NAME ECode
        GITHUB_REPOSITORY eyalamirmusic/ECode
        GIT_TAG main)
