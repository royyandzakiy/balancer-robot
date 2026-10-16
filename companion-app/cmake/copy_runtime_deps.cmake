# cmake/copy_runtime_deps.cmake — script mode (cmake -P, or include() from install(CODE)).
# Copies the non-Qt runtime DLLs that windeployqt-deployed Qt libraries and plugins need, e.g.
# meshoptimizer.dll for Qt6Quick3DRuntimeRender. windeployqt only copies Qt's own DLLs, and vcpkg's
# applocal step only follows what the exe links directly, so these are otherwise missing and a QML
# import fails with "Cannot load library ...plugin.dll: The specified module could not be found".
#
# Inputs:
#   DIR      — folder with the exe and the windeployqt output (scanned recursively)
#   DEP_DIR  — vcpkg's bin folder for this config (…/x64-windows/bin or …/x64-windows/debug/bin)
#   TOOL, TOOL_COMMAND — how GET_RUNTIME_DEPENDENCIES reads PE imports: "objdump" + llvm-objdump.exe,
#                        or "dumpbin" + dumpbin.exe

set(_stamp "${DIR}/.runtime_deps.stamp")

file(GLOB_RECURSE _dlls "${DIR}/*.dll")
# Only binaries that changed since the last run (windeployqt leaves up-to-date files untouched), so
# incremental builds skip the scan. The exe's own deps are vcpkg applocal's job.
if(EXISTS "${_stamp}")
  set(_changed "")
  foreach(_f IN LISTS _dlls)
    if("${_f}" IS_NEWER_THAN "${_stamp}")
      list(APPEND _changed "${_f}")
    endif()
  endforeach()
  set(_dlls ${_changed})
endif()

if(_dlls)
  set(CMAKE_GET_RUNTIME_DEPENDENCIES_PLATFORM "windows+pe")
  set(CMAKE_GET_RUNTIME_DEPENDENCIES_TOOL "${TOOL}")
  set(CMAKE_GET_RUNTIME_DEPENDENCIES_COMMAND "${TOOL_COMMAND}")
  # On Windows the resolver also searches PATH, which during a build can hold vcpkg's *release*
  # folders (e.g. x64-windows/bin, tools/Qt6/bin) and make debug and release Qt DLLs "conflict".
  # Search only DIR, DEP_DIR and the system folders.
  set(ENV{PATH} "$ENV{SystemRoot}/System32;$ENV{SystemRoot}")
  # DIR first: a dependency already deployed resolves there and is left alone; only the missing ones
  # resolve to DEP_DIR. System DLLs stay unresolved/excluded, which is what we want.
  file(GET_RUNTIME_DEPENDENCIES
    LIBRARIES ${_dlls}
    DIRECTORIES "${DIR}" "${DEP_DIR}"
    RESOLVED_DEPENDENCIES_VAR _resolved
    UNRESOLVED_DEPENDENCIES_VAR _unresolved
    CONFLICTING_DEPENDENCIES_PREFIX _conflict
    PRE_EXCLUDE_REGEXES "^api-ms-" "^ext-ms-"
    POST_EXCLUDE_REGEXES "[/\\\\][Ww][Ii][Nn][Dd][Oo][Ww][Ss][/\\\\]")
  foreach(_name IN LISTS _conflict_FILENAMES)
    message(WARNING "runtime deps: ${_name} found in several places, not copied: ${_conflict_${_name}}")
  endforeach()

  file(TO_CMAKE_PATH "${DEP_DIR}" _dep_dir)
  foreach(_dep IN LISTS _resolved)
    file(TO_CMAKE_PATH "${_dep}" _dep)
    get_filename_component(_name "${_dep}" NAME)
    if(_dep MATCHES "^${_dep_dir}/" AND NOT EXISTS "${DIR}/${_name}")
      message(STATUS "runtime deps: ${_name}")
      file(COPY "${_dep}" DESTINATION "${DIR}")
    endif()
  endforeach()
endif()

file(TOUCH "${_stamp}")
