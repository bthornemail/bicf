#pragma once

#include <stdbool.h>

// Starts a lightweight UDP multicast discovery responder and announcer.
// - Joins 239.255.42.42:4242
// - Periodically sends HELLO messages
// - Responds to QUERY messages with HELLO
//
// Call after WiFi has an IPv4 address.
bool udp_discovery_start(const char *device_id);

