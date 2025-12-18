#ifndef BICF_TRIE_H
#define BICF_TRIE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// A minimal deterministic trie used to build stable left/right "streams"
// keyed by UTF-8 bytes. Used for semantic indexing, e.g.:
//   mkey = "rpc/" + method_name + "@schema/" + schema_id

typedef struct bicf_trie_node bicf_trie_node_t;

typedef struct {
  uint8_t rid[32];
} bicf_rid32_t;

typedef struct {
  bicf_trie_node_t* root;
} bicf_trie_t;

typedef enum {
  // "Left" chirality picks the negative sign for the even-row middle coefficient.
  BICF_STREAM_LEFT = 0,
  // "Right" chirality picks the positive sign for the even-row middle coefficient.
  BICF_STREAM_RIGHT = 1,
} bicf_stream_chirality_t;

// Create/free a trie. Uses heap allocation.
bicf_trie_t bicf_trie_create(void);
void bicf_trie_free(bicf_trie_t* t);

// Insert a key and associate a rid with the terminal node.
// Multiple rids per key are supported; rids are stored sorted lexicographically.
bool bicf_trie_insert(bicf_trie_t* t, const uint8_t* key, size_t key_len, const uint8_t rid[32]);

// Compute a deterministic stream ID from all rids in the trie using a signed
// Pascal-triangle weighting scheme.
//
// Let rids be emitted in canonical trie order:
// - DFS by child label ascending
// - for each terminal node, its rids are emitted ascending
//
// If N rids are emitted, set row n = N-1 and weight event k (0-indexed) by:
//   coeff(k) = s(k) * C(n, k)
//
// Signs s(k) follow the "reflective" rule:
// - left side negative, right side positive
// - for even n, the middle coefficient (k = n/2) sign is chosen by chirality
//
// The stream ID is:
//   sha256("BICFSTREAMv1" || u32_le(N) || u8(chirality) || vec8_u64_le)
//
// where vec8_u64 is computed deterministically from rid bytes as described in
// `bicf_trie.c` (quantize -> Z^8 accumulator mod 2^64).
bool bicf_trie_stream_id(const bicf_trie_t* t, bicf_stream_chirality_t chirality, uint8_t out_stream_id[32]);

#endif
