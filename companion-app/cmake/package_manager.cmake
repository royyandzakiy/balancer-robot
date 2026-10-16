# cmake/package_manager.cmake
# Selects the dependency provider, driven by the PKG_MANAGER cache variable (project_options.cmake).
# Call setup_package_manager() BEFORE project().
#
#   vcpkg — default: Qt and everything else from vcpkg.json (cmake/config_vcpkg.cmake).
#   none  — bring your own: e.g. Qt from the Qt installer or an embedded SDK, found through
#           CMAKE_PREFIX_PATH or a toolchain file. fmt (and GTest's network fetch) must be available too.
#
# Switching managers needs a fresh configure (separate build dir): the toolchain is fixed at first configure.

macro(setup_package_manager)
  if(PKG_MANAGER STREQUAL "vcpkg")
    message(STATUS "[pkg] Package manager: vcpkg")
    include(cmake/config_vcpkg.cmake)
  elseif(PKG_MANAGER STREQUAL "none")
    message(STATUS "[pkg] Package manager: none (CMAKE_PREFIX_PATH / toolchain file / system packages)")
  else()
    message(FATAL_ERROR "[pkg] Invalid PKG_MANAGER='${PKG_MANAGER}' (use: vcpkg | none)")
  endif()
endmacro()
