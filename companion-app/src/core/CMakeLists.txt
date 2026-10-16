# =============================================================================
# app_core — pure C++ app logic, no Qt
# =============================================================================
# Not linked against any Qt module and AUTOMOC is off, so an accidental #include <QString> here
# fails to compile instead of quietly dragging Qt into the logic layer. Built even with
# BUILD_APP=OFF, so its tests run without Qt installed.
# =============================================================================

add_library(app_core STATIC)

target_sources(app_core
    PRIVATE
        counter.cpp
        counter.hpp
)

# Consumers include as "core/counter.hpp"
target_include_directories(app_core
    PUBLIC
        ${PROJECT_SOURCE_DIR}/src
)

set_target_properties(app_core PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
)

target_link_libraries(app_core
    PUBLIC
        fmt::fmt
)

configure_target(app_core)
