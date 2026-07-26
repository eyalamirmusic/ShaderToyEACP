set(CMAKE_FOLDER Examples)

# A hand-written port, in the shape the transpiler is being built to emit.
add_subdirectory(Plasma)

# The same shader, converted from GLSL at build time. The two drawing the same
# picture is what says the transpiler works.
add_subdirectory(PlasmaPort)

# A transpiled port that reads a texture channel, over an image the app
# generates. Nothing but a running frame shows that a channel a port declared
# reaches the draw with the texture bound to it.
add_subdirectory(TunnelPort)

# The shape stage 5 opened: a march whose length depends on what it hits, which
# no amount of unrolling reaches.
add_subdirectory(MarchPort)

# And the shape stage 8 opened: a Shadertoy with a buffer, from two .glsl files,
# whose buffer reads what it left there last frame.
add_subdirectory(TrailPort)

# All of them at once, switchable: the corpus on screen rather than in a table.
# It is also the only target that compiles every port, so a shader that converts
# but does not compile stops this build.
add_subdirectory(Gallery)
