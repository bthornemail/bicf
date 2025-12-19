#pragma once

#include "config_defaults.h"

// Optional secrets override.
#if defined(__has_include)
#if __has_include("config_local.h")
#include "config_local.h"
#endif
#endif

