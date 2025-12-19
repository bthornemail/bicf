idf_component_register(
    SRCS
        "main.c"
        "wifi_mqtt.c"
        "clbc_vm.c"
    INCLUDE_DIRS
        "."
    REQUIRES
        nvs_flash
        esp_wifi
        esp_netif
        esp_event
        mqtt
        mbedtls
        json
)

