#define _POSIX_C_SOURCE 200809L
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "../embedded/canisa-mvp/canisa_mvp.h"

static uint64_t mono_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ((uint64_t)ts.tv_sec * 1000000000ULL) + (uint64_t)ts.tv_nsec;
}

int main(int argc, char** argv) {
  int warmup = 100;
  int iterations = 10000;
  if (argc >= 2) warmup = atoi(argv[1]);
  if (argc >= 3) iterations = atoi(argv[2]);
  if (warmup < 0 || iterations <= 0) return 2;

  const uint8_t valid[] = {
    'C','A','N','B','C',0,
    1,0,
    31,0,0,0,
    0x10,0x00,0x02,0x00,0x00,0x00,
    0x20,0x01,0x00,0x01,0x00,0x00,0x00,0x00,0x00,
    0x21,0x01,0x00,0x03,0x00,
    0x30,0x01,0x00,
    0x61,0x01,0x00,0x00,
    0x93,0x00,0x00,
    0x01
  };

  canisa_mvp_result_t out;
  memset(&out, 0, sizeof(out));

  for (int i = 0; i < warmup; i++) {
    if (!canisa_mvp_run_canbc(valid, sizeof(valid), &out)) {
      printf("{\"ok\":false,\"reason\":\"warmup_failed\"}\n");
      return 3;
    }
  }

  uint64_t t0 = mono_ns();
  for (int i = 0; i < iterations; i++) {
    if (!canisa_mvp_run_canbc(valid, sizeof(valid), &out)) {
      printf("{\"ok\":false,\"reason\":\"iteration_failed\",\"iteration\":%d}\n", i);
      return 4;
    }
  }
  uint64_t t1 = mono_ns();

  uint64_t total_ns = t1 - t0;
  uint64_t ns_per_iter = total_ns / (uint64_t)iterations;
  uint64_t ops_per_sec = ns_per_iter == 0 ? 0 : (1000000000ULL / ns_per_iter);

  printf("{\"ok\":true,\"warmup\":%d,\"iterations\":%d,\"total_ns\":%llu,\"ns_per_iter\":%llu,\"ops_per_sec\":%llu,\"events\":%u,\"state_hash\":\"%s\",\"fano_hash\":\"%s\"}\n",
         warmup,
         iterations,
         (unsigned long long)total_ns,
         (unsigned long long)ns_per_iter,
         (unsigned long long)ops_per_sec,
         out.events,
         out.state_hash,
         out.fano_hash);

  return 0;
}
