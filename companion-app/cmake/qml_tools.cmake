# cmake/qml_tools.cmake
# QML formatting, hooked into the C++ format targets from cmake/format.cmake. Include AFTER
# find_package(Qt6 ... Qml) (project_dependencies.cmake), since qmlformat comes from Qt.
#
#   cmake --build <dir> --target format         # clang-format + qmlformat, in place
#   cmake --build <dir> --target format-check   # also fails on unformatted .qml (CI)
#   cmake --build <dir> --target all_qmllint    # qmllint every QML module (Qt creates this one)

if(NOT TARGET Qt6::qmlformat)
  message(STATUS "qmlformat not found; QML files are not formatted by 'format' / 'format-check'.")
  return()
endif()

file(GLOB_RECURSE QML_FORMAT_SOURCES CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/qml/*.qml" "${PROJECT_SOURCE_DIR}/test/*.qml")
if(NOT QML_FORMAT_SOURCES)
  return()
endif()

add_custom_target(
  qml-format
  COMMAND Qt6::qmlformat --inplace ${QML_FORMAT_SOURCES}
  COMMENT "qmlformat: rewriting QML sources in place"
  VERBATIM)

# qmlformat has no check mode: format each file to stdout and compare (cmake/qml_format_check.cmake).
add_custom_target(
  qml-format-check
  COMMAND ${CMAKE_COMMAND} -D "QMLFORMAT=$<TARGET_FILE:Qt6::qmlformat>" -D "FILES=${QML_FORMAT_SOURCES}" -D
          "WORK_DIR=${CMAKE_BINARY_DIR}/qml-format-check" -P "${PROJECT_SOURCE_DIR}/cmake/qml_format_check.cmake"
  COMMENT "qmlformat: checking QML sources (no changes written)"
  VERBATIM)

if(TARGET format)
  add_dependencies(format qml-format)
endif()
if(TARGET format-check)
  add_dependencies(format-check qml-format-check)
endif()
