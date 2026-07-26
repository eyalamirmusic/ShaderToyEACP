set(CMAKE_FOLDER Examples)

# A hand-written port, in the shape the transpiler is being built to emit.
add_subdirectory(Plasma)

# The same shader, converted from GLSL at build time. The two drawing the same
# picture is what says the transpiler works.
add_subdirectory(PlasmaPort)
