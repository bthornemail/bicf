#include "bicf_trie.h"

#include <stdlib.h>
#include <string.h>

#include "mbedtls/sha256.h"

typedef struct {
  uint8_t label;
  struct bicf_trie_node* child;
} child_entry_t;

struct bicf_trie_node {
  child_entry_t* children;
  size_t children_len;
  size_t children_cap;

  bicf_rid32_t* rids;
  size_t rids_len;
  size_t rids_cap;
};

static bicf_trie_node_t* node_new(void) {
  bicf_trie_node_t* n = (bicf_trie_node_t*)calloc(1, sizeof(bicf_trie_node_t));
  return n;
}

static int rid_cmp(const uint8_t a[32], const uint8_t b[32]) { return memcmp(a, b, 32); }

static bool ensure_children_cap(bicf_trie_node_t* n, size_t need) {
  if (n->children_cap >= need) return true;
  size_t cap = n->children_cap ? n->children_cap * 2 : 4;
  while (cap < need) cap *= 2;
  child_entry_t* p = (child_entry_t*)realloc(n->children, cap * sizeof(child_entry_t));
  if (!p) return false;
  n->children = p;
  n->children_cap = cap;
  return true;
}

static bool ensure_rids_cap(bicf_trie_node_t* n, size_t need) {
  if (n->rids_cap >= need) return true;
  size_t cap = n->rids_cap ? n->rids_cap * 2 : 4;
  while (cap < need) cap *= 2;
  bicf_rid32_t* p = (bicf_rid32_t*)realloc(n->rids, cap * sizeof(bicf_rid32_t));
  if (!p) return false;
  n->rids = p;
  n->rids_cap = cap;
  return true;
}

static bicf_trie_node_t* get_or_add_child(bicf_trie_node_t* n, uint8_t label) {
  // children are kept sorted by label ascending
  size_t lo = 0;
  size_t hi = n->children_len;
  while (lo < hi) {
    size_t mid = lo + (hi - lo) / 2;
    uint8_t m = n->children[mid].label;
    if (m == label) return n->children[mid].child;
    if (m < label) lo = mid + 1;
    else hi = mid;
  }

  if (!ensure_children_cap(n, n->children_len + 1)) return NULL;
  // insert at position lo
  memmove(&n->children[lo + 1], &n->children[lo], (n->children_len - lo) * sizeof(child_entry_t));
  n->children[lo].label = label;
  n->children[lo].child = node_new();
  if (!n->children[lo].child) return NULL;
  n->children_len += 1;
  return n->children[lo].child;
}

static bool insert_rid_sorted(bicf_trie_node_t* n, const uint8_t rid[32]) {
  // dedupe + insert sorted
  size_t lo = 0;
  size_t hi = n->rids_len;
  while (lo < hi) {
    size_t mid = lo + (hi - lo) / 2;
    int c = rid_cmp(n->rids[mid].rid, rid);
    if (c == 0) return true;
    if (c < 0) lo = mid + 1;
    else hi = mid;
  }
  if (!ensure_rids_cap(n, n->rids_len + 1)) return false;
  memmove(&n->rids[lo + 1], &n->rids[lo], (n->rids_len - lo) * sizeof(bicf_rid32_t));
  memcpy(n->rids[lo].rid, rid, 32);
  n->rids_len += 1;
  return true;
}

bicf_trie_t bicf_trie_create(void) {
  bicf_trie_t t;
  t.root = node_new();
  return t;
}

void bicf_trie_free(bicf_trie_t* t) {
  if (!t) return;
  // Iterative free (avoids deep recursion on long keys).
  if (!t->root) return;

  size_t stack_cap = 32;
  size_t stack_len = 0;
  bicf_trie_node_t** stack = (bicf_trie_node_t**)malloc(stack_cap * sizeof(bicf_trie_node_t*));
  if (!stack) return;

  stack[stack_len++] = t->root;
  while (stack_len) {
    bicf_trie_node_t* n = stack[--stack_len];
    if (!n) continue;

    // Push children before freeing n->children.
    for (size_t i = 0; i < n->children_len; i++) {
      if (stack_len == stack_cap) {
        size_t new_cap = stack_cap * 2;
        bicf_trie_node_t** p = (bicf_trie_node_t**)realloc(stack, new_cap * sizeof(bicf_trie_node_t*));
        if (!p) {
          // Best-effort: leak remaining nodes rather than corrupt heap.
          free(n->children);
          free(n->rids);
          free(n);
          free(stack);
          t->root = NULL;
          return;
        }
        stack = p;
        stack_cap = new_cap;
      }
      stack[stack_len++] = n->children[i].child;
    }

    free(n->children);
    free(n->rids);
    free(n);
  }
  free(stack);
  t->root = NULL;
}

bool bicf_trie_insert(bicf_trie_t* t, const uint8_t* key, size_t key_len, const uint8_t rid[32]) {
  if (!t || !t->root || (!key && key_len != 0) || !rid) return false;
  bicf_trie_node_t* cur = t->root;
  for (size_t i = 0; i < key_len; i++) {
    cur = get_or_add_child(cur, key[i]);
    if (!cur) return false;
  }
  return insert_rid_sorted(cur, rid);
}

static size_t count_emitted_rids(const bicf_trie_node_t* root) {
  if (!root) return 0;
  size_t total = 0;

  size_t stack_cap = 32;
  size_t stack_len = 0;
  const bicf_trie_node_t** stack = (const bicf_trie_node_t**)malloc(stack_cap * sizeof(*stack));
  if (!stack) return 0;

  stack[stack_len++] = root;
  while (stack_len) {
    const bicf_trie_node_t* n = stack[--stack_len];
    if (!n) continue;
    total += n->rids_len;
    for (size_t i = 0; i < n->children_len; i++) {
      if (stack_len == stack_cap) {
        size_t new_cap = stack_cap * 2;
        const bicf_trie_node_t** p = (const bicf_trie_node_t**)realloc((void*)stack, new_cap * sizeof(*stack));
        if (!p) {
          free((void*)stack);
          return total;
        }
        stack = p;
        stack_cap = new_cap;
      }
      stack[stack_len++] = n->children[i].child;
    }
  }
  free((void*)stack);
  return total;
}

static uint32_t le32(const uint8_t* p) {
  return ((uint32_t)p[0]) | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static uint64_t gcd_u64(uint64_t a, uint64_t b) {
  while (b) {
    uint64_t t = a % b;
    a = b;
    b = t;
  }
  return a;
}

// Exact binomial for values which fit in uint64.
// Avoids 128-bit arithmetic by reducing fractions with gcd before multiply.
static bool binom_u64(uint32_t n, uint32_t k, uint64_t* out) {
  if (!out) return false;
  if (k > n) return false;
  if (k > n - k) k = n - k;
  uint64_t res = 1;
  for (uint32_t i = 1; i <= k; i++) {
    uint64_t num = (uint64_t)(n - k + i);
    uint64_t den = (uint64_t)i;

    uint64_t g1 = gcd_u64(num, den);
    num /= g1;
    den /= g1;

    uint64_t g2 = gcd_u64(res, den);
    res /= g2;
    den /= g2;

    if (den != 1) return false;
    if (num != 0 && res > (UINT64_MAX / num)) return false;
    res *= num;
  }
  *out = res;
  return true;
}

static bool signed_pascal_coeff(uint32_t n, uint32_t k, bicf_stream_chirality_t chirality, int64_t* out_coeff) {
  if (!out_coeff) return false;
  uint64_t c;
  if (!binom_u64(n, k, &c)) return false;

  int sign = +1;
  if (n == 0) {
    // Single element row: treat as +1.
    sign = +1;
  } else if ((n % 2) == 0 && k == (n / 2)) {
    // Middle coefficient in even row is chirality-selected.
    sign = (chirality == BICF_STREAM_RIGHT) ? +1 : -1;
  } else {
    // Reflective split: left side negative, right side positive.
    // For odd n, indices < (n+1)/2 are negative.
    // For even n, indices < n/2 are negative.
    uint32_t threshold = (n / 2);
    if ((n % 2) == 1) threshold = (n + 1) / 2;
    sign = (k < threshold) ? -1 : +1;
    if (k == n) sign = +1;
  }

  // Safe for demo sizes; c fits in uint64, convert to signed (may still exceed int64 for large n).
  if (c > (uint64_t)INT64_MAX) return false;
  *out_coeff = (int64_t)c * (int64_t)sign;
  return true;
}

static void sha256_bytes(const uint8_t* data, size_t len, uint8_t out32[32]) {
  mbedtls_sha256_context sha;
  mbedtls_sha256_init(&sha);
  mbedtls_sha256_starts(&sha, 0);
  mbedtls_sha256_update(&sha, data, len);
  mbedtls_sha256_finish(&sha, out32);
  mbedtls_sha256_free(&sha);
}

static void stream_hash_final(uint32_t n_events, bicf_stream_chirality_t chirality, const uint64_t z8[8],
                              uint8_t out_stream_id[32]) {
  // "BICFSTREAMv1" || u32_le(N) || u8(chirality) || 8*u64_le
  uint8_t buf[12 + 4 + 1 + 8 * 8];
  memset(buf, 0, sizeof(buf));
  memcpy(buf, "BICFSTREAMv1", 12);
  buf[12] = (uint8_t)(n_events & 0xff);
  buf[13] = (uint8_t)((n_events >> 8) & 0xff);
  buf[14] = (uint8_t)((n_events >> 16) & 0xff);
  buf[15] = (uint8_t)((n_events >> 24) & 0xff);
  buf[16] = (uint8_t)chirality;
  for (size_t i = 0; i < 8; i++) {
    uint64_t w = z8[i];
    size_t off = 17 + i * 8;
    buf[off + 0] = (uint8_t)(w & 0xff);
    buf[off + 1] = (uint8_t)((w >> 8) & 0xff);
    buf[off + 2] = (uint8_t)((w >> 16) & 0xff);
    buf[off + 3] = (uint8_t)((w >> 24) & 0xff);
    buf[off + 4] = (uint8_t)((w >> 32) & 0xff);
    buf[off + 5] = (uint8_t)((w >> 40) & 0xff);
    buf[off + 6] = (uint8_t)((w >> 48) & 0xff);
    buf[off + 7] = (uint8_t)((w >> 56) & 0xff);
  }
  sha256_bytes(buf, sizeof(buf), out_stream_id);
}

bool bicf_trie_stream_id(const bicf_trie_t* t, bicf_stream_chirality_t chirality, uint8_t out_stream_id[32]) {
  if (!t || !t->root || !out_stream_id) return false;

  size_t n_total = count_emitted_rids(t->root);
  if (n_total == 0) {
    memset(out_stream_id, 0, 32);
    return true;
  }
  // This demo stream uses exact binomials; keep it bounded.
  if (n_total > 64) return false;

  uint32_t n = (uint32_t)(n_total - 1);  // row index
  uint32_t k = 0;

  uint64_t acc[8];
  for (size_t i = 0; i < 8; i++) acc[i] = 0;

  // Iterative pre-order DFS matching canonical emission order.
  typedef struct {
    const bicf_trie_node_t* node;
    size_t next_child;
    bool emitted;
  } frame_t;

  size_t stack_cap = 32;
  size_t stack_len = 0;
  frame_t* stack = (frame_t*)malloc(stack_cap * sizeof(frame_t));
  if (!stack) return false;
  stack[stack_len++] = (frame_t){.node = t->root, .next_child = 0, .emitted = false};

  while (stack_len) {
    frame_t* f = &stack[stack_len - 1];
    const bicf_trie_node_t* cur = f->node;
    if (!cur) {
      stack_len--;
      continue;
    }

    if (!f->emitted) {
      for (size_t i = 0; i < cur->rids_len; i++) {
        if (k > n) break;
        int64_t coeff = 0;
        if (!signed_pascal_coeff(n, k, chirality, &coeff)) {
          free(stack);
          return false;
        }

        // quantize: rid bytes -> Z^8 words (signed int32), accumulate mod 2^64
        const uint8_t* r = cur->rids[i].rid;
        for (size_t j = 0; j < 8; j++) {
          int32_t w = (int32_t)le32(&r[j * 4]);
          uint64_t coeff_mod = (uint64_t)coeff;
          uint64_t w_mod = (uint64_t)(int64_t)w;
          uint64_t prod = coeff_mod * w_mod;
          acc[j] += prod;
        }
        k++;
      }
      f->emitted = true;
      continue;
    }

    if (f->next_child < cur->children_len) {
      const bicf_trie_node_t* child = cur->children[f->next_child].child;
      f->next_child++;

      if (stack_len == stack_cap) {
        size_t new_cap = stack_cap * 2;
        frame_t* p = (frame_t*)realloc(stack, new_cap * sizeof(frame_t));
        if (!p) {
          free(stack);
          return false;
        }
        stack = p;
        stack_cap = new_cap;
      }
      stack[stack_len++] = (frame_t){.node = child, .next_child = 0, .emitted = false};
      continue;
    }

    stack_len--;
  }
  free(stack);

  stream_hash_final((uint32_t)n_total, chirality, acc, out_stream_id);
  return true;
}
