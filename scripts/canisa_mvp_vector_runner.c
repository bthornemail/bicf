#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "../embedded/canisa-mvp/canisa_mvp.h"

static void print_case_ok(const char* name, const canisa_mvp_result_t* out) {
  printf("{\"case\":\"%s\",\"ok\":true,\"events\":%u,\"state_hash\":\"%s\",\"fano_hash\":\"%s\"}\n",
         name, out->events, out->state_hash, out->fano_hash);
}

static void print_case_fail(const char* name) {
  printf("{\"case\":\"%s\",\"ok\":false}\n", name);
}

int main(void) {
  // valid_case payload bytes:
  // DEF_MOD(0,2), TERM_NEW(dst=1, coeff=1, exp2=0), TERM_SET_VAR(1,3), STATE_ADD(1), STATE_HASH(1,0), PROJ_FANO(0), HALT
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

  // invalid modulus p=3
  const uint8_t bad_mod[] = {
    'C','A','N','B','C',0,
    1,0,
    7,0,0,0,
    0x10,0x00,0x03,0x00,0x00,0x00,
    0x01
  };

  canisa_mvp_result_t out;
  memset(&out, 0, sizeof(out));
  bool ok1 = canisa_mvp_run_canbc(valid, sizeof(valid), &out);
  if (!ok1 || !out.ok) {
    print_case_fail("state_hash_path");
    return 2;
  }
  print_case_ok("state_hash_path", &out);

  memset(&out, 0, sizeof(out));
  bool ok2 = canisa_mvp_run_canbc(bad_mod, sizeof(bad_mod), &out);
  if (ok2) {
    print_case_fail("bad_modulus_should_fail");
    return 3;
  }
  print_case_fail("bad_modulus_expected_failure");

  return 0;
}
