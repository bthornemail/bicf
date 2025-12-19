#ifndef CANVASL_PICO_H
#define CANVASL_PICO_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "nrr_pico.h"

// CanvasL interpreter for Pico 2 / Pico 2 W (experimental)
// Simplified implementation for memory-constrained environments

// Maximum vector/matrix dimensions
#define CANVASL_MAX_DIM 16
#define CANVASL_MAX_VECTOR_SIZE CANVASL_MAX_DIM
#define CANVASL_MAX_MATRIX_ROWS CANVASL_MAX_DIM
#define CANVASL_MAX_MATRIX_COLS CANVASL_MAX_DIM

// Maximum environment entries
#define CANVASL_MAX_ENV_ENTRIES 32

// Maximum JSONL line length
#define CANVASL_MAX_LINE_LEN 512

// Vector type
typedef struct {
    float values[CANVASL_MAX_VECTOR_SIZE];
    size_t len;
} canvasl_vector_t;

// Matrix type
typedef struct {
    float values[CANVASL_MAX_MATRIX_ROWS][CANVASL_MAX_MATRIX_COLS];
    size_t rows;
    size_t cols;
} canvasl_matrix_t;

// Encoder type
typedef enum {
    CANVASL_ENCODER_AFFINE = 0
} canvasl_encoder_kind_t;

typedef struct {
    canvasl_encoder_kind_t kind;
    char A_ref[NRR_REF_STRING_SIZE];  // Reference to matrix A
    char b_ref[NRR_REF_STRING_SIZE];  // Reference to vector b
    size_t basis_dim;
} canvasl_encoder_t;

// Environment entry
typedef struct {
    char ref[NRR_REF_STRING_SIZE];
    enum {
        CANVASL_ENV_VECTOR,
        CANVASL_ENV_MATRIX,
        CANVASL_ENV_ENCODER
    } type;
    union {
        canvasl_vector_t vector;
        canvasl_matrix_t matrix;
        canvasl_encoder_t encoder;
    } value;
} canvasl_env_entry_t;

// CanvasL context
typedef struct {
    nrr_context_t nrr;
    canvasl_env_entry_t env[CANVASL_MAX_ENV_ENTRIES];
    size_t env_count;
    uint32_t last_phase;
    char last_boundary_id[64];
} canvasl_context_t;

// Initialize CanvasL context
void canvasl_init(canvasl_context_t *ctx);

// Parse and execute a single JSONL line
// Returns true on success, false on error
bool canvasl_execute_line(canvasl_context_t *ctx, const char *jsonl_line);

// Execute a step (for programmatic use)
// op: "define_encoder", "apply_encoder", "decode_and_validate"
// Returns true on success
bool canvasl_execute_step(canvasl_context_t *ctx, const char *op, ...);

// Get value from environment by reference
bool canvasl_env_get_vector(canvasl_context_t *ctx, const char *ref, canvasl_vector_t *vec_out);
bool canvasl_env_get_matrix(canvasl_context_t *ctx, const char *ref, canvasl_matrix_t *mat_out);
bool canvasl_env_get_encoder(canvasl_context_t *ctx, const char *ref, canvasl_encoder_t *enc_out);

// Set value in environment
bool canvasl_env_set_vector(canvasl_context_t *ctx, const char *ref, const canvasl_vector_t *vec);
bool canvasl_env_set_matrix(canvasl_context_t *ctx, const char *ref, const canvasl_matrix_t *mat);
bool canvasl_env_set_encoder(canvasl_context_t *ctx, const char *ref, const canvasl_encoder_t *enc);

// Linear algebra operations
void canvasl_mat_vec_mul(const canvasl_matrix_t *A, const canvasl_vector_t *x, canvasl_vector_t *y_out);
void canvasl_vec_add(const canvasl_vector_t *a, const canvasl_vector_t *b, canvasl_vector_t *c_out);

// Validation operations (simplified)
bool canvasl_validate_fano(const canvasl_vector_t *decoded, const char *boundary_id);
bool canvasl_validate_pcg(const canvasl_vector_t *decoded, const char *boundary_id);

#endif  // CANVASL_PICO_H
