set(CMAKE_FOLDER Tests)

find_package(NanoTest REQUIRED)

add_subdirectory(Corpus)
add_subdirectory(Coverage)
add_subdirectory(Glsl)
add_subdirectory(Runtime)
