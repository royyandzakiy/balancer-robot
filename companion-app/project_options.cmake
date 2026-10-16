# project_options.cmake — shared project defaults (committed, applies to all developers).
#
# These are option() calls: they set a default value that can be overridden by:
#   1. project_options.local.cmake (gitignored, personal) — included BEFORE this file
#   2. CMake presets (CMakePresets.json) — cacheVariables
#   3. Command line: cmake -DENABLE_TRACY=ON ..

# ------ Compiler Warnings ------
option(ENABLE_STRICT_COMPILER "Warnings become errors (-Werror / /WX)" OFF)

# ------ Project Features ------
option(BUILD_APP "Build the Qt/QML application (src/ + qml/); OFF builds only the Qt-free src/core" ON)
option(BUILD_TESTING "Build the tests under test/ (GTest, QtTest, Qt Quick Test)" OFF)

# ------ Package Manager ------
# vcpkg: Qt and everything else from vcpkg.json (default).
# none:  bring your own (e.g. Qt from the Qt installer or an embedded SDK via CMAKE_PREFIX_PATH / a toolchain file).
set(PKG_MANAGER "vcpkg" CACHE STRING "Dependency provider: vcpkg | none")
set_property(CACHE PKG_MANAGER PROPERTY STRINGS vcpkg none)

# ------ Sanitizers ------
# UBSan is the baseline (always enabled with sanitizers, GCC/Clang). Pick AT MOST ONE of ASan / TSan
# (mutually exclusive). Windows supports ASan only (msvc-asan preset). MSan is not offered: it needs
# every library — Qt included — built with it.
option(ENABLE_SANITIZERS "Enable runtime sanitizers (UBSan baseline)" OFF)
if(ENABLE_SANITIZERS)
  option(ENABLE_ASAN "AddressSanitizer + LeakSanitizer — detects buffer overflows, use-after-free, leaks" OFF)
  option(ENABLE_TSAN "ThreadSanitizer — detects data races and deadlocks (Linux/macOS)" OFF)
endif()

# ------ UI Automation (E2E) ------
# Embeds the Spix server in the app: it listens on a TCP port (9000, or SPIX_PORT) and lets scripts
# click and read QML items. For test builds only — never ship a build with this ON.
option(ENABLE_SPIX "Embed the Spix UI-automation server for E2E tests (test/e2e/)" OFF)

# ------ Linters & Static Analyzers ------
option(ENABLE_CLANG_TIDY "Run clang-tidy on first-party production code (no-op if clang-tidy isn't installed)" OFF)

# ------ Coverage ------
# GCC/Clang on Linux/macOS (clang-cl/MSVC not supported).
option(ENABLE_COVERAGE "Instrument for code coverage and add the 'coverage' target (runs tests + generates report)" OFF)

# ------ Compile-Time Optimizations ------
option(ENABLE_CCACHE "Wrap compiles in ccache — huge speedup when switching branches or re-configuring" OFF)
option(ENABLE_FAST_LINKER "Use mold/lld instead of default linker — dramatically faster linking (no-op if absent)" OFF)
option(ENABLE_PCH "Precompile heavy headers (STL, …) — faster full builds, slower single-file incremental rebuilds" OFF)
option(ENABLE_UNITY_BUILD "Batch .cpp files into unity translation units — fastest clean builds, kills incremental builds" OFF)

# ------ Runtime Profiler ------
# For QML-side performance use Qt's own qmlprofiler / Qt Creator's QML Profiler.
option(ENABLE_TRACY "Tracy: real-time low-overhead sampling profiler for the C++ side (CPU, memory, locks, zones)" OFF)
