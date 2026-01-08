#include "udp_discovery.h"

#include <string.h>
#include <stdio.h>

#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "lwip/sockets.h"
#include "lwip/inet.h"
#include "lwip/ip4_addr.h"
#include "lwip/netdb.h"

static const char *TAG = "udp_discovery";

#define DISCOVERY_GROUP "239.255.42.42"
#define DISCOVERY_PORT 4242
#define DISCOVERY_TTL  1

static bool g_started = false;
static char g_device_id[32] = {0};

static const char *k_query = "BICF_DISCOVERY_QUERY";
static const char *k_hello_prefix = "BICF_DISCOVERY_HELLO ";

static void send_hello(int sock, const struct sockaddr_in *mcast_addr) {
    char msg[160];
    // Plain-text: easy to parse without JSON libs on the host.
    // Example: "BICF_DISCOVERY_HELLO esp32-a\n"
    snprintf(msg, sizeof(msg), "%s%s\n", k_hello_prefix, g_device_id);
    (void)sendto(sock, msg, (int)strlen(msg), 0, (const struct sockaddr *)mcast_addr, sizeof(*mcast_addr));
}

static void discovery_task(void *arg) {
    (void)arg;

    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sock < 0) {
        ESP_LOGE(TAG, "socket() failed");
        g_started = false;
        vTaskDelete(NULL);
        return;
    }

    int reuse = 1;
    (void)setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    struct sockaddr_in bind_addr = {0};
    bind_addr.sin_family = AF_INET;
    bind_addr.sin_port = htons(DISCOVERY_PORT);
    bind_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(sock, (struct sockaddr *)&bind_addr, sizeof(bind_addr)) < 0) {
        ESP_LOGE(TAG, "bind() failed");
        close(sock);
        g_started = false;
        vTaskDelete(NULL);
        return;
    }

    struct ip_mreq mreq = {0};
    mreq.imr_multiaddr.s_addr = inet_addr(DISCOVERY_GROUP);
    mreq.imr_interface.s_addr = htonl(INADDR_ANY);
    if (setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, sizeof(mreq)) < 0) {
        ESP_LOGE(TAG, "IP_ADD_MEMBERSHIP failed (multicast may be blocked by AP)");
        // Continue anyway: the host can still receive our periodic hellos via sendto().
    }

    int ttl = DISCOVERY_TTL;
    (void)setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl));

    struct sockaddr_in mcast_addr = {0};
    mcast_addr.sin_family = AF_INET;
    mcast_addr.sin_port = htons(DISCOVERY_PORT);
    mcast_addr.sin_addr.s_addr = inet_addr(DISCOVERY_GROUP);

    int64_t last_hello_us = 0;
    const int64_t hello_interval_us = 1000LL * 1000LL;  // 1s

    while (1) {
        int64_t now = esp_timer_get_time();
        if (now - last_hello_us >= hello_interval_us) {
            send_hello(sock, &mcast_addr);
            last_hello_us = now;
        }

        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(sock, &rfds);
        struct timeval tv = {0};
        tv.tv_sec = 0;
        tv.tv_usec = 200 * 1000;  // 200ms

        int r = select(sock + 1, &rfds, NULL, NULL, &tv);
        if (r <= 0) {
            continue;
        }

        char buf[256];
        struct sockaddr_in from = {0};
        socklen_t from_len = sizeof(from);
        int n = recvfrom(sock, buf, sizeof(buf) - 1, 0, (struct sockaddr *)&from, &from_len);
        if (n <= 0) {
            continue;
        }
        buf[n] = '\0';

        if (strncmp(buf, k_query, strlen(k_query)) == 0) {
            // Respond with HELLO on multicast (host will see it as long as peer traffic works).
            send_hello(sock, &mcast_addr);
        }
    }
}

bool udp_discovery_start(const char *device_id) {
    if (g_started) {
        return true;
    }
    if (!device_id || !device_id[0]) {
        return false;
    }
    strncpy(g_device_id, device_id, sizeof(g_device_id) - 1);
    g_device_id[sizeof(g_device_id) - 1] = '\0';

    g_started = true;
    BaseType_t ok = xTaskCreate(discovery_task, "bicf_discovery", 4096, NULL, 4, NULL);
    if (ok != pdPASS) {
        g_started = false;
        return false;
    }
    ESP_LOGI(TAG, "UDP discovery started on %s:%d (multicast %s)", "0.0.0.0", DISCOVERY_PORT, DISCOVERY_GROUP);
    return true;
}

