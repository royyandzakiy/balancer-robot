# cmake/profiler.cmake
# Tracy runtime profiler for the C++ side (QML-side performance: use qmlprofiler / Qt Creator's QML Profiler).
#
# ENABLE_TRACY=ON pulls tracy from vcpkg (the "tracy" manifest feature, see cmake/config_vcpkg.cmake) and
# creates project_tracy_profile, which configure_target() links into first-party targets.

if(ENABLE_TRACY)
  find_package(tracy CONFIG QUIET)
  if(tracy_FOUND)
    if(NOT TARGET project_tracy_profile)
      add_library(project_tracy_profile INTERFACE)
      target_link_libraries(project_tracy_profile INTERFACE Tracy::TracyClient)
      target_compile_definitions(project_tracy_profile INTERFACE TRACY_ENABLE)
    endif()
    message(STATUS "Tracy runtime profiling ENABLED via project_tracy_profile")
  else()
    message(WARNING "ENABLE_TRACY is ON but tracy wasn't found (vcpkg 'tracy' feature) — profiling disabled.")
  endif()
endif()
