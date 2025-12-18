# Minimal pico-sdk import shim.
# Usage:
#   export PICO_SDK_PATH=/path/to/pico-sdk
#   mkdir build && cd build
#   cmake .. -DPICO_BOARD=pico2

if (DEFINED ENV{PICO_SDK_PATH})
  set(PICO_SDK_PATH $ENV{PICO_SDK_PATH})
endif()

if (NOT PICO_SDK_PATH)
  message(FATAL_ERROR "PICO_SDK_PATH not set. Install pico-sdk and export PICO_SDK_PATH=/path/to/pico-sdk")
endif()

include(${PICO_SDK_PATH}/external/pico_sdk_import.cmake)

