# cmake/packaging.cmake
# CPack: zips what `cmake --install` produces (the exe plus the Qt runtime from the deploy script
# in src/CMakeLists.txt). Include AFTER the targets and their install() rules.
#
#   cmake --build --preset clang-cl-release
#   cpack --config build/clang-cl-release/CPackConfig.cmake
#     -> build/clang-cl-release/package/<name>-<version>-win64.zip

set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VENDOR "${PROJECT_NAME}") # change to your name / org
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_NAME} — Qt/QML application")
set(CPACK_GENERATOR "ZIP")
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/package")
set(CPACK_STRIP_FILES ON)

include(CPack)
