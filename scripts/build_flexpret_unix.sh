#!/usr/bin/env bash

# Project root is one up from the bin directory.
PROJECT_ROOT=$LF_BIN_DIRECTORY/..
COPY_FROM=$PROJECT_ROOT/copy

echo "Generating a Makefile for FlexPRET in $LF_SOURCE_GEN_DIRECTORY"
echo "Current directory is $(pwd)"

# Parse filename from the src-gen directory name
# https://stackoverflow.com/questions/3162385/how-to-split-a-string-in-shell-and-get-the-last-field
LF_FILENAME=${LF_SOURCE_GEN_DIRECTORY##*/} # Get the LF filename without the .lf extension.
echo "The LF filename is $LF_FILENAME.lf."

# Copy c files into /core.
cp "$COPY_FROM/platform/lf_flexpret_support.c" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/impl/src"
cp "$COPY_FROM/platform/lf_atomic_irq.c" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/impl/src"

# Copy header files into /include.
cp "$COPY_FROM/platform/lf_flexpret_support.h" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/api/platform"
cp "$COPY_FROM/platform/low_level_platform.h" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/api"

# Copy CMakeLists.txt
cp "$COPY_FROM/platform/impl/CMakeLists.txt" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/impl"
cp "$COPY_FROM/platform/api/CMakeLists.txt" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/api"

# Need to generate top-level CMakeLists.txt because some of it depends on variables
printf '
set(LF_FILENAME %s)
string(TOLOWER ${LF_FILENAME} LF_FILENAME_LOWER)

cmake_minimum_required(VERSION 3.19)

include($ENV{FP_SDK_PATH}/cmake/riscv-toolchain.cmake)
project(${LF_FILENAME} LANGUAGES C ASM)

set(CMAKE_SYSTEM_NAME "FLEXPRET")

if(CMAKE_BUILD_TYPE STREQUAL "Test")
  set(CMAKE_BUILD_TYPE "Debug")
  if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
    find_program(LCOV_BIN lcov)
    if(LCOV_BIN MATCHES "lcov$")
      set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --coverage -fprofile-arcs -ftest-coverage")
    else()
      message("Not producing code coverage information since lcov was not found")
    endif()
  else()
    message("Not producing code coverage information since the selected compiler is no gcc")
  endif()
endif()
# Require C11
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Require C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(DEFAULT_BUILD_TYPE Debug)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE ${DEFAULT_BUILD_TYPE} CACHE STRING "Choose the type of build." FORCE)
endif()

# do not print install messages
set(CMAKE_INSTALL_MESSAGE NEVER)
# Colorize compilation output
set(CMAKE_COLOR_DIAGNOSTICS ON)

# Set default values for build parameters
if (NOT DEFINED SCHEDULER)
    set(SCHEDULER SCHED_NP)
endif()
if (NOT DEFINED LF_REACTION_GRAPH_BREADTH)
    set(LF_REACTION_GRAPH_BREADTH 4)
endif()
if (NOT DEFINED NUMBER_OF_WORKERS)
    set(NUMBER_OF_WORKERS 3)
endif()
if (NOT DEFINED LOG_LEVEL)
    set(LOG_LEVEL 2)
endif()
if (NOT DEFINED NUMBER_OF_WATCHDOGS)
    set(NUMBER_OF_WATCHDOGS 0)
endif()
add_subdirectory(core)

set(LF_MAIN_TARGET ${LF_FILENAME})

# Declare a new executable target and list all its sources
add_executable(
    ${LF_MAIN_TARGET}
    lib/schedule.c
    _${LF_FILENAME_LOWER}_main.c
    _printhi.c
    ${LF_FILENAME}.c
)

find_library(MATH_LIBRARY m)
if(MATH_LIBRARY)
  target_link_libraries(${LF_MAIN_TARGET} PUBLIC ${MATH_LIBRARY})
endif()
target_link_libraries(${LF_MAIN_TARGET} PUBLIC reactor-c)
target_include_directories(${LF_MAIN_TARGET} PUBLIC .)
target_include_directories(${LF_MAIN_TARGET} PUBLIC include/)
target_include_directories(${LF_MAIN_TARGET} PUBLIC include/api)
target_include_directories(${LF_MAIN_TARGET} PUBLIC include/core)
target_include_directories(${LF_MAIN_TARGET} PUBLIC include/core/platform)
target_include_directories(${LF_MAIN_TARGET} PUBLIC include/core/modal_models)
target_include_directories(${LF_MAIN_TARGET} PUBLIC include/core/utils)

# TODO: Could include hwconfig.cmake here

# Set the number of workers to enable threading/tracing
target_compile_definitions(${LF_MAIN_TARGET} PUBLIC 
  NUMBER_OF_WORKERS=3 NO_TTY
)
	
add_subdirectory($ENV{FP_SDK_PATH} BINARY_DIR)

# FlexPRET specific changes
# (Remember: Language ASM probably required)
include($ENV{FP_SDK_PATH}/cmake/fp-app.cmake)

set(CMAKE_EXECUTABLE_SUFFIX ".riscv")
fp_add_dump_output(${LF_MAIN_TARGET})
fp_add_mem_output(${LF_MAIN_TARGET})


    install(
        TARGETS ${LF_MAIN_TARGET}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
' "$LF_FILENAME" > "$LF_SOURCE_GEN_DIRECTORY/CMakeLists.txt"

echo "Created $LF_SOURCE_GEN_DIRECTORY/CMakeLists.txt"

cd "$LF_SOURCE_GEN_DIRECTORY"
cmake -B build && cmake --build build

echo ""
echo "**** To get simulation outputs:"
echo "cd $LF_SOURCE_GEN_DIRECTORY; fp-emu +ispm=$LF_FILENAME.mem"
echo ""
