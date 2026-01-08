cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(pico2w_mqtt_clbc C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

option(PICO2W_MQTT_CLBC_USE_LOCAL_CONFIG "Include src/config_local.h for WiFi/MQTT secrets" ON)
option(PICO2W_MQTT_CLBC_ENABLE_USB_STDIO "Enable USB stdio (debugging)" OFF)
option(PICO2W_MQTT_CLBC_ENABLE_UART_STDIO "Enable UART stdio (debugging)" OFF)

add_executable(pico2w_mqtt_clbc
  src/main.c
  src/clbc_vm.c
  src/sha256.c
  ../canisa-mvp/canisa_mvp.c
  ../canisa-mvp/canisa_poly_f2.c
)

target_include_directories(pico2w_mqtt_clbc PRIVATE src ../canisa-mvp)

target_link_libraries(pico2w_mqtt_clbc
  pico_stdlib
  pico_cyw43_arch_lwip_threadsafe_background
  pico_lwip_mqtt
)

if (PICO2W_MQTT_CLBC_USE_LOCAL_CONFIG)
  target_compile_definitions(pico2w_mqtt_clbc PRIVATE PICO2W_MQTT_CLBC_USE_LOCAL_CONFIG=1)
endif()

pico_enable_stdio_uart(pico2w_mqtt_clbc 0)
pico_enable_stdio_usb(pico2w_mqtt_clbc 0)

if (PICO2W_MQTT_CLBC_ENABLE_USB_STDIO)
  pico_enable_stdio_usb(pico2w_mqtt_clbc 1)
endif()

if (PICO2W_MQTT_CLBC_ENABLE_UART_STDIO)
  pico_enable_stdio_uart(pico2w_mqtt_clbc 1)
endif()

pico_add_extra_outputs(pico2w_mqtt_clbc)
