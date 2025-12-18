cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(pico2_clbc_test C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(pico2_clbc_test
  src/main.c
  src/clbc_vm.c
  src/sha256.c
  src/usb_descriptors.c
)

target_include_directories(pico2_clbc_test PRIVATE src)

target_link_libraries(pico2_clbc_test
  pico_stdlib
  tinyusb_device
  tinyusb_board
)

pico_enable_stdio_uart(pico2_clbc_test 0)
pico_enable_stdio_usb(pico2_clbc_test 0)

pico_add_extra_outputs(pico2_clbc_test)
