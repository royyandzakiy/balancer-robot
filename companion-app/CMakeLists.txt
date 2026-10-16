cmake_minimum_required(VERSION 3.28)

#=========================
# Project Options & Package Manager
#=========================
include(project_options.local.cmake OPTIONAL) # create & modify to change locally (only for you)
include(project_options.cmake) # modify to change for all developers

# If this project is consumed via add_subdirectory(), the parent owns the provider/toolchain, hence
# omit this setup_package_manager(). But because before project(), PROJECT_IS_TOP_LEVEL isn't set yet
# hence use the source-dir check
include(cmake/package_manager.cmake)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  setup_package_manager() # dispatches to vcpkg / none per PKG_MANAGER
endif()

#=========================
# Project Configuration
#=========================
include(cmake/version.cmake) # reads version.txt -> PROJECT_VERSION_STRING (before project())
project(
  balancer-robot-desktop-companion
  LANGUAGES CXX
  VERSION ${PROJECT_VERSION_STRING})

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

#=========================
# Formatter, Linter, Profiler, Accelerator
#=========================
if(PROJECT_IS_TOP_LEVEL) # format & setup clangd
  include(cmake/format.cmake) # format / format-check / tidy-all targets
  include(cmake/clangd.cmake) # mirror compile_commands.json for clangd
endif()

include(cmake/compiler.cmake)            # warnings, strict, build-type guard
include(cmake/build_acceleration.cmake)  # fast linker (mold/lld) + ccache

include(cmake/sanitizers.cmake)          # ASan/TSan/UBSan flags + deploy_asan_runtime()
include(cmake/analyzers.cmake)           # clang-tidy discovery
include(cmake/profiler.cmake)            # Tracy (when ENABLE_TRACY)
include(cmake/configure_target.cmake)    # defines configure_target() — PCH, unity, tidy, profiler link, ASan deploy
include(cmake/qt_deploy.cmake)           # deploy_qt_runtime() / install_qt_runtime() — windeployqt + qt.conf (Windows)
if(BUILD_TESTING)
  # Before the targets: its instrumentation flags only reach targets created after this include.
  include(cmake/coverage.cmake)          # coverage flags + setup_coverage_target() (when ENABLE_COVERAGE)
endif()

#=========================
# Dependencies
#=========================
include(project_dependencies.cmake)
if(BUILD_APP AND PROJECT_IS_TOP_LEVEL)
  include(cmake/qml_tools.cmake) # qmlformat into format / format-check (needs Qt found)
endif()

#=========================
# Targets
#=========================
add_subdirectory(src/core) # pure C++ logic, no Qt (always built, so its tests run without Qt)
if(BUILD_APP)
  add_subdirectory(qml) # static QML module (URI App): UI + viewmodels, linked into the app as a plugin
  add_subdirectory(src) # the Qt/QML application
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/packaging.cmake) # cpack ZIP of the installed app
  endif()
endif()

#=========================
# Tests & Coverage
#=========================
if(BUILD_TESTING)
  enable_testing() # ctest / gtest_discover_tests register the unit tests
  add_subdirectory(test)
  if(ENABLE_COVERAGE AND TARGET unit_tests)
    setup_coverage_target(unit_tests) # adds the `coverage` target (runs tests + reports)
  endif()
endif()
