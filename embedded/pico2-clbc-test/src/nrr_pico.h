#ifndef NRR_PICO_H
#define NRR_PICO_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// NRR (Native Repository Runtime) for Pico W2
// Content-addressed storage + append-only log

// Maximum content size (adjust based on available RAM)
#define NRR_MAX_CONTENT_SIZE 4096
#define NRR_MAX_ENTRIES 64
#define NRR_HASH_SIZE 32
#define NRR_REF_STRING_SIZE 65  // "nrr:" + 64 hex chars

// Log entry types
typedef enum {
    NRR_LOG_BOUNDARY = 0,
    NRR_LOG_INTERIOR = 1,
    NRR_LOG_GUARANTEE = 2
} nrr_log_type_t;

// Log entry structure
typedef struct {
    uint32_t phase;
    nrr_log_type_t type;
    char ref[NRR_REF_STRING_SIZE];
} nrr_log_entry_t;

// Storage entry (content-addressed)
typedef struct {
    char ref[NRR_REF_STRING_SIZE];
    uint8_t content[NRR_MAX_CONTENT_SIZE];
    size_t content_len;
} nrr_storage_entry_t;

// NRR context
typedef struct {
    nrr_storage_entry_t storage[NRR_MAX_ENTRIES];
    size_t storage_count;
    nrr_log_entry_t log[NRR_MAX_ENTRIES];
    size_t log_count;
} nrr_context_t;

// Initialize NRR context
void nrr_init(nrr_context_t *ctx);

// Store content, return reference (SHA-256 hash as hex string)
// Returns true on success, false on error (e.g., out of memory)
bool nrr_put(nrr_context_t *ctx, const uint8_t *content, size_t content_len, char *ref_out);

// Retrieve content by reference
// Returns content length on success, 0 on not found
size_t nrr_get(nrr_context_t *ctx, const char *ref, uint8_t *content_out, size_t max_len);

// Append log entry
bool nrr_append(nrr_context_t *ctx, uint32_t phase, nrr_log_type_t type, const char *ref);

// Get all log entries
size_t nrr_log(nrr_context_t *ctx, nrr_log_entry_t *entries_out, size_t max_entries);

// Get log entry count
size_t nrr_log_size(nrr_context_t *ctx);

// Clear log (for testing)
void nrr_log_clear(nrr_context_t *ctx);

// Helper: Compute SHA-256 hash and format as hex string
void nrr_hash_to_ref(const uint8_t *hash, char *ref_out);

#endif  // NRR_PICO_H

