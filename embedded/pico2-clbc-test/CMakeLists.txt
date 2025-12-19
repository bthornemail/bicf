cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(pico2_clbc_test C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

option(PICO2_CLBC_ENABLE_EXPERIMENTAL_NRR "Build experimental NRR module (not required for CLBT demo)" OFF)
option(PICO2_CLBC_ENABLE_EXPERIMENTAL_CANVASL "Build experimental CanvasL/JSONL interpreter (placeholders for FANO/PCG)" OFF)
option(PICO2_CLBC_ENABLE_EXPERIMENTAL_WIFI_MQTT "Build experimental WiFi/MQTT stubs (Pico W / Pico 2 W class only)" OFF)

add_executable(pico2_clbc_test
  src/main.c
  src/clbc_vm.c
  src/sha256.c
  src/usb_descriptors.c
)

if (PICO2_CLBC_ENABLE_EXPERIMENTAL_NRR)
  target_sources(pico2_clbc_test PRIVATE src/nrr_pico.c)
endif()

if (PICO2_CLBC_ENABLE_EXPERIMENTAL_CANVASL)
  target_sources(pico2_clbc_test PRIVATE src/canvasl_pico.c src/json_parser_minimal.c)
endif()

if (PICO2_CLBC_ENABLE_EXPERIMENTAL_WIFI_MQTT)
  target_sources(pico2_clbc_test PRIVATE src/wifi_pico.c src/mqtt_client_pico.c)
endif()

target_include_directories(pico2_clbc_test PRIVATE src)

target_link_libraries(pico2_clbc_test
  pico_stdlib
  tinyusb_device
  tinyusb_board
)

pico_enable_stdio_uart(pico2_clbc_test 0)
pico_enable_stdio_usb(pico2_clbc_test 0)

pico_add_extra_outputs(pico2_clbc_test)
