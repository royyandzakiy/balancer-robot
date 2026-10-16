# =============================================================================
# App QML module — the UI (.qml) plus the C++ types QML uses directly (viewmodels)
# =============================================================================
# A STATIC module linked into the executable through its plugin target (app_qmlplugin), so the
# QML files stay in qml/ (same layout as nexus-test-tool-qml) instead of next to main.cpp.
#   - New .qml file: add it to QML_FILES (subfolders are fine; types are named by file name).
#   - New QML_ELEMENT class: add its .hpp/.cpp to SOURCES (they live in src/viewmodels/).
# The URI "App" is generic on purpose, so new projects only rename project() in the root.
# =============================================================================

qt_add_qml_module(app_qml
    URI App
    VERSION 1.0
    STATIC
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/App # must end in the URI path, or qmllint/qmlls can't resolve it
    QML_FILES
        Main.qml
        components/CounterCard.qml
        components/ModelViewer.qml
    SOURCES
        ${PROJECT_SOURCE_DIR}/src/viewmodels/counter_view_model.hpp
        ${PROJECT_SOURCE_DIR}/src/viewmodels/counter_view_model.cpp
)

# The generated type registration includes viewmodel headers by bare file name.
target_include_directories(app_qml
    PUBLIC
        ${PROJECT_SOURCE_DIR}/src/viewmodels
)

target_link_libraries(app_qml
    PUBLIC
        app_core
        Qt6::Qml
        Qt6::Quick3D # ModelViewer.qml (QtQuick3D); qmlcachegen's compiled QML links against it
)
