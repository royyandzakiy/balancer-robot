# cmake/spix.cmake
# Spix (https://github.com/faaxm/spix): UI automation for Qt Quick over XML-RPC. Linked into the app
# only when ENABLE_SPIX=ON; test/e2e/ drives it from Python. Include AFTER find_package(Qt6).
#
# AnyRPC comes from vcpkg (the "spix" manifest feature, switched on by ENABLE_SPIX in
# cmake/config_vcpkg.cmake). vcpkg's anyrpc installs no CMake config, and Spix's FindAnyRPC module
# would create AnyRPC::anyrpc inside Spix's directory scope, invisible to our app target, which
# links it transitively through static SpixCore. So the imported target is created here, at the top
# level, and Spix's FindAnyRPC sees it already exists.

find_path(AnyRPC_INCLUDE_DIRS anyrpc/anyrpc.h)
find_library(AnyRPC_LIBRARIES NAMES anyrpc)
if(NOT AnyRPC_INCLUDE_DIRS OR NOT AnyRPC_LIBRARIES)
  message(FATAL_ERROR "[spix] AnyRPC not found — ENABLE_SPIX needs the vcpkg 'spix' feature (anyrpc)")
endif()
if(NOT TARGET AnyRPC::anyrpc)
  add_library(AnyRPC::anyrpc UNKNOWN IMPORTED GLOBAL)
  set_target_properties(AnyRPC::anyrpc PROPERTIES IMPORTED_LOCATION "${AnyRPC_LIBRARIES}"
                                                  INTERFACE_INCLUDE_DIRECTORIES "${AnyRPC_INCLUDE_DIRS}")
  if(WIN32)
    set_property(TARGET AnyRPC::anyrpc PROPERTY INTERFACE_LINK_LIBRARIES ws2_32)
  endif()
endif()

set(SPIX_QT_MAJOR 6 CACHE STRING "" FORCE)
set(SPIX_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SPIX_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(SPIX_BUILD_QTQUICK ON CACHE BOOL "" FORCE)
set(SPIX_BUILD_QTWIDGETS OFF CACHE BOOL "" FORCE)

include(FetchContent)
FetchContent_Declare(
  spix
  GIT_REPOSITORY https://github.com/faaxm/spix.git
  GIT_TAG v0.14
  SYSTEM)
FetchContent_MakeAvailable(spix)

# Third-party: don't apply our warning policy (cmake/compiler.cmake) to it. AUTOMOC off because
# Spix runs qt6_wrap_cpp itself; qt_standard_project_setup's global AUTOMOC would moc twice.
foreach(t SpixCore SpixQtQuick)
  if(TARGET ${t})
    target_compile_options(${t} PRIVATE -w)
    set_target_properties(${t} PROPERTIES AUTOMOC OFF)
  endif()
endforeach()

message(STATUS "[spix] UI automation server ENABLED — test builds only, do not ship")
