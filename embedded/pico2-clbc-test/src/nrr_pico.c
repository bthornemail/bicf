#include "nrr_pico.h"
#include "sha256.h"
#include <string.h>

// Initialize NRR context
void nrr_init(nrr_context_t *ctx) {
    if (!ctx) return;
    memset(ctx, 0, sizeof(nrr_context_t));
}

// Compute SHA-256 hash and format as "nrr:<hex>"
static void compute_ref(const uint8_t *content, size_t content_len, char *ref_out) {
    uint8_t hash[NRR_HASH_SIZE];
    bicf_sha256_ctx_t ctx;
    bicf_sha256_init(&ctx);
    bicf_sha256_update(&ctx, content, content_len);
    bicf_sha256_final(&ctx, hash);
    nrr_hash_to_ref(hash, ref_out);
}

// Store content, return reference
bool nrr_put(nrr_context_t *ctx, const uint8_t *content, size_t content_len, char *ref_out) {
    if (!ctx || !content || !ref_out || content_len == 0 || content_len > NRR_MAX_CONTENT_SIZE) {
        return false;
    }

    // Check if we have space
    if (ctx->storage_count >= NRR_MAX_ENTRIES) {
        return false;
    }

    // Compute reference
    compute_ref(content, content_len, ref_out);

    // Check if already stored (deduplication)
    for (size_t i = 0; i < ctx->storage_count; i++) {
        if (strcmp(ctx->storage[i].ref, ref_out) == 0) {
            // Already stored, just return the reference
            return true;
        }
    }

    // Store new content
    nrr_storage_entry_t *entry = &ctx->storage[ctx->storage_count];
    strncpy(entry->ref, ref_out, NRR_REF_STRING_SIZE - 1);
    entry->ref[NRR_REF_STRING_SIZE - 1] = '\0';
    memcpy(entry->content, content, content_len);
    entry->content_len = content_len;
    ctx->storage_count++;

    return true;
}

// Retrieve content by reference
size_t nrr_get(nrr_context_t *ctx, const char *ref, uint8_t *content_out, size_t max_len) {
    if (!ctx || !ref || !content_out) {
        return 0;
    }

    // Find entry by reference
    for (size_t i = 0; i < ctx->storage_count; i++) {
        if (strcmp(ctx->storage[i].ref, ref) == 0) {
            size_t copy_len = ctx->storage[i].content_len;
            if (copy_len > max_len) {
                copy_len = max_len;
            }
            memcpy(content_out, ctx->storage[i].content, copy_len);
            return ctx->storage[i].content_len;
        }
    }

    return 0;  // Not found
}

// Append log entry
bool nrr_append(nrr_context_t *ctx, uint32_t phase, nrr_log_type_t type, const char *ref) {
    if (!ctx || !ref) {
        return false;
    }

    // Check if we have space
    if (ctx->log_count >= NRR_MAX_ENTRIES) {
        return false;
    }

    // Add log entry
    nrr_log_entry_t *entry = &ctx->log[ctx->log_count];
    entry->phase = phase;
    entry->type = type;
    strncpy(entry->ref, ref, NRR_REF_STRING_SIZE - 1);
    entry->ref[NRR_REF_STRING_SIZE - 1] = '\0';
    ctx->log_count++;

    return true;
}

// Get all log entries (in reverse order, like Scheme implementation)
size_t nrr_log(nrr_context_t *ctx, nrr_log_entry_t *entries_out, size_t max_entries) {
    if (!ctx || !entries_out) {
        return 0;
    }

    size_t copy_count = ctx->log_count;
    if (copy_count > max_entries) {
        copy_count = max_entries;
    }

    // Copy in reverse order (most recent first)
    for (size_t i = 0; i < copy_count; i++) {
        size_t src_idx = ctx->log_count - 1 - i;
        entries_out[i] = ctx->log[src_idx];
    }

    return ctx->log_count;
}

// Get log entry count
size_t nrr_log_size(nrr_context_t *ctx) {
    if (!ctx) return 0;
    return ctx->log_count;
}

// Clear log (for testing)
void nrr_log_clear(nrr_context_t *ctx) {
    if (!ctx) return;
    ctx->log_count = 0;
}

// Helper: Format SHA-256 hash as "nrr:<hex>" reference
void nrr_hash_to_ref(const uint8_t *hash, char *ref_out) {
    if (!hash || !ref_out) return;

    // Write "nrr:" prefix
    strcpy(ref_out, "nrr:");

    // Append hex-encoded hash
    const char hex[] = "0123456789abcdef";
    for (size_t i = 0; i < NRR_HASH_SIZE; i++) {
        ref_out[4 + i * 2] = hex[(hash[i] >> 4) & 0x0F];
        ref_out[4 + i * 2 + 1] = hex[hash[i] & 0x0F];
    }
    ref_out[4 + NRR_HASH_SIZE * 2] = '\0';
}

