#ifndef PICO2W_MQTT_CLBC_CONFIG_H
#define PICO2W_MQTT_CLBC_CONFIG_H

#include "config_defaults.h"

// Optional secrets override. Create src/config_local.h (ignored by git) with your real values.
#if defined(PICO2W_MQTT_CLBC_USE_LOCAL_CONFIG) && defined(__has_include)
#if __has_include("config_local.h")
#include "config_local.h"
#endif
#endif

#endif
