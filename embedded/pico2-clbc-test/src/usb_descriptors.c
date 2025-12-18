#include "tusb.h"

#include <string.h>

enum {
  ITF_NUM_CDC = 0,
  ITF_NUM_CDC_DATA,
  ITF_NUM_TOTAL
};

enum {
  EP_CDC_NOTIF = 0x81,
  EP_CDC_OUT = 0x02,
  EP_CDC_IN = 0x83
};

#define CONFIG_TOTAL_LEN (TUD_CONFIG_DESC_LEN + TUD_CDC_DESC_LEN)

static tusb_desc_device_t const k_desc_device = {
  .bLength = sizeof(tusb_desc_device_t),
  .bDescriptorType = TUSB_DESC_DEVICE,
  .bcdUSB = 0x0200,

  .bDeviceClass = TUSB_CLASS_MISC,
  .bDeviceSubClass = MISC_SUBCLASS_COMMON,
  .bDeviceProtocol = MISC_PROTOCOL_IAD,

  .bMaxPacketSize0 = CFG_TUD_ENDPOINT0_SIZE,

  .idVendor = 0xCafe,
  .idProduct = 0x4011,
  .bcdDevice = 0x0100,

  .iManufacturer = 0x01,
  .iProduct = 0x02,
  .iSerialNumber = 0x03,

  .bNumConfigurations = 0x01
};

uint8_t const* tud_descriptor_device_cb(void) { return (uint8_t const*)&k_desc_device; }

static uint8_t const k_desc_configuration[] = {
  TUD_CONFIG_DESCRIPTOR(1, ITF_NUM_TOTAL, 0, CONFIG_TOTAL_LEN, 0x00, 100),
  TUD_CDC_DESCRIPTOR(ITF_NUM_CDC, 4, EP_CDC_NOTIF, 8, EP_CDC_OUT, EP_CDC_IN, 64),
};

uint8_t const* tud_descriptor_configuration_cb(uint8_t index) {
  (void)index;
  return k_desc_configuration;
}

static const char* k_string_desc_arr[] = {
  (const char[]){0x09, 0x04},  // 0: English (0x0409)
  "BICF",                      // 1: Manufacturer
  "Pico2 CLBT",                // 2: Product
  "0001",                      // 3: Serial (placeholder)
  "CLBT CDC",                  // 4: CDC interface
};

static uint16_t k_desc_str[32];

uint16_t const* tud_descriptor_string_cb(uint8_t index, uint16_t langid) {
  (void)langid;

  uint8_t chr_count;
  if (index == 0) {
    memcpy(&k_desc_str[1], k_string_desc_arr[0], 2);
    chr_count = 1;
  } else {
    if (index >= sizeof(k_string_desc_arr) / sizeof(k_string_desc_arr[0])) return NULL;
    const char* str = k_string_desc_arr[index];
    chr_count = (uint8_t)strlen(str);
    if (chr_count > 31) chr_count = 31;
    for (uint8_t i = 0; i < chr_count; i++) k_desc_str[1 + i] = (uint16_t)str[i];
  }

  k_desc_str[0] = (uint16_t)((TUSB_DESC_STRING << 8) | (2 * chr_count + 2));
  return k_desc_str;
}
