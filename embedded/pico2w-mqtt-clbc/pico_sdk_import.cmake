if (DEFINED ENV{PICO_SDK_PATH})
  set(PICO_SDK_PATH $ENV{PICO_SDK_PATH})
endif()

if (NOT PICO_SDK_PATH)
  message(FATAL_ERROR "PICO_SDK_PATH not set. Run embedded/pico2-clbc-test/bootstrap.sh first or export PICO_SDK_PATH=/path/to/pico-sdk")
endif()

include(${PICO_SDK_PATH}/external/pico_sdk_import.cmake)

