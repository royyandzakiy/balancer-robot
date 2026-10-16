# cmake/qml_format_check.cmake — script mode (cmake -P), driven by the qml-format-check target.
# Inputs: QMLFORMAT (tool path), FILES (;-list of .qml), WORK_DIR (scratch dir in the build tree).

file(MAKE_DIRECTORY "${WORK_DIR}")
set(_unformatted "")
foreach(_file IN LISTS FILES)
  get_filename_component(_name "${_file}" NAME)
  set(_out "${WORK_DIR}/${_name}")
  execute_process(COMMAND "${QMLFORMAT}" "${_file}" OUTPUT_FILE "${_out}" RESULT_VARIABLE _rc)
  if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "qmlformat failed on ${_file}")
  endif()
  execute_process(COMMAND "${CMAKE_COMMAND}" -E compare_files --ignore-eol "${_file}" "${_out}" RESULT_VARIABLE _diff)
  if(NOT _diff EQUAL 0)
    list(APPEND _unformatted "${_file}")
  endif()
endforeach()

if(_unformatted)
  list(JOIN _unformatted "\n  " _list)
  message(FATAL_ERROR "Unformatted QML (run the 'format' target):\n  ${_list}")
endif()
