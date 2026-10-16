# test/CMakeLists.txt
# =============================================================================
# GTest Setup (shared by unit_tests and the sanitizer trip-wires; viewmodel_tests uses QtTest)
# =============================================================================
# find_package(GTest CONFIG REQUIRED) # need to add `gtest` in vcpkg.json
include(FetchContent)
FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG v1.17.0
  SYSTEM)
set(gtest_force_shared_crt
    ON
    CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE) # don't let gtest add install rules to this project
FetchContent_MakeAvailable(googletest)

# surpress warnings from gtest libraries
foreach(t gtest gtest_main gmock gmock_main)
  if(TARGET ${t})
    target_compile_options(${t} PRIVATE -w)
  endif()
endforeach()

include(GoogleTest)
# Discover tests at ctest time, not build time: under Windows ASan the test exe needs a runtime
# DLL that's only deployed during the build, so a build-time test run can fail to start.
set(CMAKE_GTEST_DISCOVER_TESTS_DISCOVERY_MODE PRE_TEST)

# =============================================================================
# Unit tests — GTest on src/core (pure C++). No Qt needed, so these also run with BUILD_APP=OFF.
# =============================================================================
add_executable(unit_tests test_counter.cpp)
target_link_libraries(unit_tests PRIVATE app_core GTest::gtest_main)
set_target_properties(unit_tests PROPERTIES AUTOMOC OFF)
gtest_discover_tests(unit_tests)

# =============================================================================
# Viewmodel tests — QtTest on the QML_ELEMENT classes in the App module (links the static module,
# so it tests exactly what the app runs). vcpkg copies the Qt DLLs next to the test exe.
# =============================================================================
if(BUILD_APP)
  add_executable(viewmodel_tests test_counter_view_model.cpp)
  target_link_libraries(viewmodel_tests PRIVATE app_qml Qt6::Test)
  add_test(NAME viewmodel_tests COMMAND viewmodel_tests)

  # ===========================================================================
  # QML tests — Qt Quick Test runs every test/qml/tst_*.qml (TestCase items: component tests and a
  # Main.qml smoke test). Builds into the same bin/<preset>/ as the app, so it finds QtQuick.Controls
  # through the app's windeployqt deploy + qt.conf there.
  # ===========================================================================
  add_executable(qml_tests qml/tst_qml_main.cpp)
  target_link_libraries(qml_tests PRIVATE app_qmlplugin Qt6::QuickTest Qt6::QuickControls2)
  target_compile_definitions(qml_tests PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
  add_dependencies(qml_tests ${PROJECT_NAME}) # make sure the Qt runtime deploy has run
  add_test(NAME qml_tests COMMAND qml_tests)

  # On Windows, QtTest logs to OutputDebugString (invisible) unless a console is attached, which it
  # isn't under ctest or CI. Force normal output so failures show up in --output-on-failure / CI logs.
  set_tests_properties(viewmodel_tests qml_tests PROPERTIES ENVIRONMENT "QT_FORCE_STDERR_LOGGING=1")

  # ===========================================================================
  # E2E tests — Python drives the real app through Spix (ENABLE_SPIX=ON builds only).
  # ===========================================================================
  if(ENABLE_SPIX)
    find_package(Python3 COMPONENTS Interpreter REQUIRED)
    add_test(NAME e2e_counter COMMAND Python3::Interpreter "${CMAKE_CURRENT_SOURCE_DIR}/e2e/test_counter_e2e.py"
                                      --app "$<TARGET_FILE:${PROJECT_NAME}>")
    # One app instance on the Spix port at a time.
    set_tests_properties(e2e_counter PROPERTIES RUN_SERIAL ON TIMEOUT 120)
  endif()
endif()

# =============================================================================
# Sanitizer trip-wires — verify each sanitizer actually CATCHES its bug class.
# Built only when ENABLE_SANITIZERS (so they inherit the sanitizer flags from
# cmake/sanitizers.cmake). Each is a ctest test that PASSES when the
# sanitizer's diagnostic appears in the output — if a trip-wire runs clean, the
# sanitizer silently isn't working and the test goes red.
# =============================================================================
if(ENABLE_SANITIZERS)
  add_executable(sanitizer_tests sanitizers/sanitizer_tests.cpp)
  target_link_libraries(sanitizer_tests PRIVATE GTest::gtest GTest::gtest_main)
  set_target_properties(sanitizer_tests PROPERTIES AUTOMOC OFF)
  # Compile in only the death tests whose sanitizer is actually active in this build.
  if(MSVC)
    # Windows (MSVC/clang-cl): only ASan exists — no UBSan baseline, no LSan.
    if(ENABLE_ASAN)
      target_compile_definitions(sanitizer_tests PRIVATE SANITIZER_ASAN)
    endif()
  else()
    # GCC/Clang: UBSan is always the baseline, plus one of ASan(+LSan)/TSan.
    target_compile_definitions(sanitizer_tests PRIVATE SANITIZER_UBSAN)
    if(ENABLE_ASAN)
      target_compile_definitions(sanitizer_tests PRIVATE SANITIZER_ASAN SANITIZER_LSAN)
    elseif(ENABLE_TSAN)
      find_package(Threads REQUIRED)
      target_link_libraries(sanitizer_tests PRIVATE Threads::Threads)
      target_compile_definitions(sanitizer_tests PRIVATE SANITIZER_TSAN)
    endif()
  endif()
  # TSan defaults to report-and-continue; force termination on the first finding so the
  # EXPECT_DEATH tests observe a death. (ASan/UBSan already halt.)
  gtest_discover_tests(sanitizer_tests PROPERTIES ENVIRONMENT "TSAN_OPTIONS=halt_on_error=1")
  # Windows ASan: the runtime DLL must sit next to the test exe (shared bin/ dir covers all exes).
  if(ENABLE_ASAN)
    deploy_asan_runtime(sanitizer_tests)
  endif()
endif()
