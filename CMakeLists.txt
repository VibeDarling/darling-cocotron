project(cocotron)

# Drawing, text and view display all run on the CPU here, and unoptimized
# they are several times slower, so build them optimized even when no build
# type is set and the rest of the tree is built at -O0.
if(NOT CMAKE_BUILD_TYPE)
	add_compile_options(-O2)
endif()

add_subdirectory(CoreGraphics)
add_subdirectory(Onyx2D)
add_subdirectory(AppKit)
add_subdirectory(CoreText)
add_subdirectory(Cocoa)
add_subdirectory(CoreData)
add_subdirectory(QuartzCore)
