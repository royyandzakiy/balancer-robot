# =============================================================================
# The Qt/QML application (target name = project name)
# =============================================================================
# C++ entry point only; the UI lives in the App QML module under qml/, the logic in src/core/.
# =============================================================================

# ---- Executable -------------------------------------------------------------
qt_add_executable(${PROJECT_NAME})

# ---- Sources ----------------------------------------------------------------
target_sources(${PROJECT_NAME}
    PRIVATE
        main.cpp
        $<$<PLATFORM_ID:Windows>:${PROJECT_SOURCE_DIR}/resources/app.rc> # exe icon
)

# ---- Properties -------------------------------------------------------------
set_target_properties(${PROJECT_NAME} PROPERTIES
    WIN32_EXECUTABLE $<NOT:$<CONFIG:Debug>> # console (qDebug / QML warnings) only in Debug
    MACOSX_BUNDLE TRUE
    CXX_EXTENSIONS OFF
)

# ---- Compile Definitions ----------------------------------------------------
# Shown in the window title via Qt.application.name / Qt.application.version
target_compile_definitions(${PROJECT_NAME}
    PRIVATE
        APP_NAME="${PROJECT_NAME}"
        APP_VERSION="${PROJECT_VERSION}"
)

# ---- Dependencies -----------------------------------------------------------
target_link_libraries(${PROJECT_NAME}
    PRIVATE
        app_qmlplugin            # static App QML module (qml/), imported in main.cpp
        Qt6::Quick
        Qt6::QuickControls2
)

# Spix UI-automation server for test/e2e/ (cmake/spix.cmake). Test builds only.
if(ENABLE_SPIX)
    target_link_libraries(${PROJECT_NAME} PRIVATE Spix::QtQuick)
    target_compile_definitions(${PROJECT_NAME} PRIVATE APP_ENABLE_SPIX)
endif()

# ---- Cross-Cutting Configuration --------------------------------------------
# PCH, unity build, profiler links, clang-tidy, ASan deploy — see cmake/configure_target.cmake
configure_target(${PROJECT_NAME})
deploy_qt_runtime(${PROJECT_NAME}) # dev-time: run straight from bin/<preset>/

# ---- Install / Release Deploy -----------------------------------------------
# `cmake --install <build> --prefix <dir>` gives a self-contained folder (exe + Qt runtime + qt.conf);
# cpack zips it (see cmake/packaging.cmake).
if(ENABLE_SPIX)
    message(WARNING "ENABLE_SPIX is ON: this build opens a UI-automation port — do not install or ship it")
endif()
include(GNUInstallDirs)
install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
# Same windeployqt + qt.conf as the dev deploy (Qt's qt_generate_deploy_qml_app_script missed the
# Controls style DLLs and all non-Qt vcpkg DLLs with this setup).
install_qt_runtime(${PROJECT_NAME} DESTINATION ${CMAKE_INSTALL_BINDIR})

message(STATUS "${PROJECT_NAME} configured (Qt ${Qt6_VERSION})")
