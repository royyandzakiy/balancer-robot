# cmake/version.cmake
# Single source of truth for the project version: version.txt.
#
# Included BEFORE project(): reads version.txt into PROJECT_VERSION_STRING so
# project(... VERSION ${PROJECT_VERSION_STRING}) uses it. The app sees it as APP_VERSION
# (src/CMakeLists.txt) and QML as Qt.application.version; cpack names the zip with it.

if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../version.txt")
  file(READ "${CMAKE_CURRENT_LIST_DIR}/../version.txt" _version_raw)
  string(STRIP "${_version_raw}" PROJECT_VERSION_STRING)
  unset(_version_raw)
else()
  set(PROJECT_VERSION_STRING "0.1.0")
  message(WARNING "version.txt not found; defaulting to ${PROJECT_VERSION_STRING}. Create version.txt containing X.Y.Z")
endif()
