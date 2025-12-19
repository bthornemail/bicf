#ifndef _LWIPOPTS_H
#define _LWIPOPTS_H

// Pico SDK cyw43_arch_lwip_threadsafe_background requires NO_SYS=1 (RAW lwIP API).
#define NO_SYS 1

#define LWIP_SOCKET 0
#define LWIP_NETCONN 0

#define LWIP_RAW 1
#define LWIP_TCP 1
#define LWIP_UDP 1

#define LWIP_DHCP 1
#define LWIP_DNS 1
#define LWIP_NETIF_HOSTNAME 1
#define LWIP_NETIF_STATUS_CALLBACK 1

// Memory tuning (conservative defaults).
#define MEM_ALIGNMENT 4
#define MEM_SIZE (24 * 1024)

#define MEMP_NUM_PBUF 16
#define MEMP_NUM_TCP_PCB 8
#define MEMP_NUM_TCP_PCB_LISTEN 4
#define MEMP_NUM_TCP_SEG 16
#define PBUF_POOL_SIZE 16
#define PBUF_POOL_BUFSIZE 1520

// TCP tuning for small devices.
#define TCP_MSS 1460
#define TCP_SND_BUF (4 * TCP_MSS)
#define TCP_WND (4 * TCP_MSS)

// Enable the mqtt app (we link pico_lwip_mqtt).
#define LWIP_ALTCP 0

#endif

