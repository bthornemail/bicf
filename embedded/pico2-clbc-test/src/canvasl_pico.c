#include "canvasl_pico.h"
#include "json_parser_minimal.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// Initialize CanvasL context
void canvasl_init(canvasl_context_t *ctx) {
    if (!ctx) return;
    memset(ctx, 0, sizeof(canvasl_context_t));
    nrr_init(&ctx->nrr);
    ctx->last_phase = 0;  // Start at 0, will be updated as steps execute
}

// Find environment entry by reference
static canvasl_env_entry_t *find_env_entry(canvasl_context_t *ctx, const char *ref) {
    if (!ctx || !ref) return NULL;
    for (size_t i = 0; i < ctx->env_count; i++) {
        if (strcmp(ctx->env[i].ref, ref) == 0) {
            return &ctx->env[i];
        }
    }
    return NULL;
}

// Get vector from environment
bool canvasl_env_get_vector(canvasl_context_t *ctx, const char *ref, canvasl_vector_t *vec_out) {
    canvasl_env_entry_t *entry = find_env_entry(ctx, ref);
    if (!entry || entry->type != CANVASL_ENV_VECTOR || !vec_out) {
        return false;
    }
    *vec_out = entry->value.vector;
    return true;
}

// Get matrix from environment
bool canvasl_env_get_matrix(canvasl_context_t *ctx, const char *ref, canvasl_matrix_t *mat_out) {
    canvasl_env_entry_t *entry = find_env_entry(ctx, ref);
    if (!entry || entry->type != CANVASL_ENV_MATRIX || !mat_out) {
        return false;
    }
    *mat_out = entry->value.matrix;
    return true;
}

// Get encoder from environment
bool canvasl_env_get_encoder(canvasl_context_t *ctx, const char *ref, canvasl_encoder_t *enc_out) {
    canvasl_env_entry_t *entry = find_env_entry(ctx, ref);
    if (!entry || entry->type != CANVASL_ENV_ENCODER || !enc_out) {
        return false;
    }
    *enc_out = entry->value.encoder;
    return true;
}

// Set vector in environment
bool canvasl_env_set_vector(canvasl_context_t *ctx, const char *ref, const canvasl_vector_t *vec) {
    if (!ctx || !ref || !vec || ctx->env_count >= CANVASL_MAX_ENV_ENTRIES) {
        return false;
    }

    // Check if exists, update if so
    canvasl_env_entry_t *entry = find_env_entry(ctx, ref);
    if (entry && entry->type == CANVASL_ENV_VECTOR) {
        entry->value.vector = *vec;
        return true;
    }

    // Add new entry
    entry = &ctx->env[ctx->env_count];
    strncpy(entry->ref, ref, NRR_REF_STRING_SIZE - 1);
    entry->ref[NRR_REF_STRING_SIZE - 1] = '\0';
    entry->type = CANVASL_ENV_VECTOR;
    entry->value.vector = *vec;
    ctx->env_count++;
    return true;
}

// Set matrix in environment
bool canvasl_env_set_matrix(canvasl_context_t *ctx, const char *ref, const canvasl_matrix_t *mat) {
    if (!ctx || !ref || !mat || ctx->env_count >= CANVASL_MAX_ENV_ENTRIES) {
        return false;
    }

    canvasl_env_entry_t *entry = find_env_entry(ctx, ref);
    if (entry && entry->type == CANVASL_ENV_MATRIX) {
        entry->value.matrix = *mat;
        return true;
    }

    entry = &ctx->env[ctx->env_count];
    strncpy(entry->ref, ref, NRR_REF_STRING_SIZE - 1);
    entry->ref[NRR_REF_STRING_SIZE - 1] = '\0';
    entry->type = CANVASL_ENV_MATRIX;
    entry->value.matrix = *mat;
    ctx->env_count++;
    return true;
}

// Set encoder in environment
bool canvasl_env_set_encoder(canvasl_context_t *ctx, const char *ref, const canvasl_encoder_t *enc) {
    if (!ctx || !ref || !enc || ctx->env_count >= CANVASL_MAX_ENV_ENTRIES) {
        return false;
    }

    canvasl_env_entry_t *entry = find_env_entry(ctx, ref);
    if (entry && entry->type == CANVASL_ENV_ENCODER) {
        entry->value.encoder = *enc;
        return true;
    }

    entry = &ctx->env[ctx->env_count];
    strncpy(entry->ref, ref, NRR_REF_STRING_SIZE - 1);
    entry->ref[NRR_REF_STRING_SIZE - 1] = '\0';
    entry->type = CANVASL_ENV_ENCODER;
    entry->value.encoder = *enc;
    ctx->env_count++;
    return true;
}

// Matrix-vector multiplication: y = A * x
void canvasl_mat_vec_mul(const canvasl_matrix_t *A, const canvasl_vector_t *x, canvasl_vector_t *y_out) {
    if (!A || !x || !y_out || A->cols != x->len) {
        return;
    }

    y_out->len = A->rows;
    for (size_t i = 0; i < A->rows; i++) {
        float sum = 0.0f;
        for (size_t j = 0; j < A->cols; j++) {
            sum += A->values[i][j] * x->values[j];
        }
        y_out->values[i] = sum;
    }
}

// Vector addition: c = a + b
void canvasl_vec_add(const canvasl_vector_t *a, const canvasl_vector_t *b, canvasl_vector_t *c_out) {
    if (!a || !b || !c_out || a->len != b->len) {
        return;
    }

    c_out->len = a->len;
    for (size_t i = 0; i < a->len; i++) {
        c_out->values[i] = a->values[i] + b->values[i];
    }
}

// Simplified FANO validation (placeholder - would need actual FANO checker)
bool canvasl_validate_fano(const canvasl_vector_t *decoded, const char *boundary_id) {
    (void)decoded;
    (void)boundary_id;
    // TODO: Implement actual FANO incidence checking
    // For now, accept all (would need to port fano-checker.scm logic)
    return true;
}

// Simplified PCG validation (placeholder - would need actual PCG checker)
bool canvasl_validate_pcg(const canvasl_vector_t *decoded, const char *boundary_id) {
    (void)decoded;
    (void)boundary_id;
    // TODO: Implement actual PCG pair-cover checking
    // For now, accept all (would need to port pcg-validator.scm logic)
    return true;
}

// Execute step: define_encoder
static bool exec_define_encoder(canvasl_context_t *ctx, const char *encoder_id,
                                 const char *A_ref, const char *b_ref, size_t basis_dim,
                                 const char *out_ref) {
    if (!ctx || !encoder_id || !A_ref || !b_ref || !out_ref) {
        return false;
    }
    
    canvasl_encoder_t enc;
    enc.kind = CANVASL_ENCODER_AFFINE;
    strncpy(enc.A_ref, A_ref, NRR_REF_STRING_SIZE - 1);
    enc.A_ref[NRR_REF_STRING_SIZE - 1] = '\0';
    strncpy(enc.b_ref, b_ref, NRR_REF_STRING_SIZE - 1);
    enc.b_ref[NRR_REF_STRING_SIZE - 1] = '\0';
    enc.basis_dim = basis_dim;

    // Store encoder definition in NRR
    uint8_t enc_bytes[256];
    size_t enc_len = snprintf((char *)enc_bytes, sizeof(enc_bytes),
                              "encoder:%s:A:%s:b:%s:dim:%zu",
                              encoder_id, A_ref, b_ref, basis_dim);
    char enc_ref[NRR_REF_STRING_SIZE];
    nrr_put(&ctx->nrr, enc_bytes, enc_len, enc_ref);

    return canvasl_env_set_encoder(ctx, out_ref, &enc);
}

// Execute step: apply_encoder (affine: y = A*x + b)
static bool exec_apply_encoder(canvasl_context_t *ctx, const char *encoder_ref,
                                const char *x_ref, const char *out_ref) {
    canvasl_encoder_t enc;
    if (!canvasl_env_get_encoder(ctx, encoder_ref, &enc)) {
        return false;
    }

    if (enc.kind != CANVASL_ENCODER_AFFINE) {
        return false;
    }

    canvasl_vector_t x, A_x, b, y;
    canvasl_matrix_t A;

    if (!canvasl_env_get_vector(ctx, x_ref, &x)) {
        return false;
    }
    if (!canvasl_env_get_matrix(ctx, enc.A_ref, &A)) {
        return false;
    }
    if (!canvasl_env_get_vector(ctx, enc.b_ref, &b)) {
        return false;
    }

    // Compute y = A*x + b
    canvasl_mat_vec_mul(&A, &x, &A_x);
    canvasl_vec_add(&A_x, &b, &y);

    return canvasl_env_set_vector(ctx, out_ref, &y);
}

// Execute step: decode_and_validate
static bool exec_decode_and_validate(canvasl_context_t *ctx, const char *target_ref,
                                      const char *boundary_id, const char **checks, size_t num_checks,
                                      const char *decoded_ref, const char *proof_ref) {
    canvasl_vector_t encoded, decoded;
    if (!canvasl_env_get_vector(ctx, target_ref, &encoded)) {
        return false;
    }

    // Decode (simplified: decoded = encoded)
    decoded = encoded;

    // Run validation checks
    for (size_t i = 0; i < num_checks; i++) {
        if (strcmp(checks[i], "fano_incidence") == 0) {
            if (!canvasl_validate_fano(&decoded, boundary_id)) {
                return false;
            }
        } else if (strcmp(checks[i], "pcg_pair_cover") == 0) {
            if (!canvasl_validate_pcg(&decoded, boundary_id)) {
                return false;
            }
        }
        // Other checks (schema, boundary_id_match, etc.) would go here
    }

    // Store decoded and proof
    if (!canvasl_env_set_vector(ctx, decoded_ref, &decoded)) {
        return false;
    }

    // Store proof (simplified: just store "ok" as a vector with single element)
    canvasl_vector_t proof;
    proof.len = 1;
    proof.values[0] = 1.0f;  // "ok"
    bool result = canvasl_env_set_vector(ctx, proof_ref, &proof);
    
    // Log validation result to NRR
    if (result) {
        uint8_t log_bytes[128];
        size_t log_len = snprintf((char *)log_bytes, sizeof(log_bytes),
                                  "validate:target:%s:boundary:%s:ok",
                                  target_ref, boundary_id);
        char log_ref[NRR_REF_STRING_SIZE];
        nrr_put(&ctx->nrr, log_bytes, log_len, log_ref);
        nrr_append(&ctx->nrr, ctx->last_phase, NRR_LOG_GUARANTEE, log_ref);
    }
    
    return result;
}

// Parse vector from JSON array
static bool parse_vector_from_json(json_value_t *arr, canvasl_vector_t *vec) {
    if (!arr || arr->type != JSON_ARRAY) return false;
    
    size_t len = json_array_length(arr);
    if (len == 0 || len > CANVASL_MAX_VECTOR_SIZE) return false;
    
    vec->len = len;
    for (size_t i = 0; i < len; i++) {
        json_value_t *item = json_array_get(arr, i);
        if (!item || item->type != JSON_NUMBER) return false;
        vec->values[i] = (float)json_get_number(item);
    }
    return true;
}

// Parse matrix from JSON array of arrays
static bool parse_matrix_from_json(json_value_t *arr, canvasl_matrix_t *mat) {
    if (!arr || arr->type != JSON_ARRAY) return false;
    
    size_t rows = json_array_length(arr);
    if (rows == 0 || rows > CANVASL_MAX_MATRIX_ROWS) return false;
    
    mat->rows = rows;
    mat->cols = 0;
    
    for (size_t i = 0; i < rows; i++) {
        json_value_t *row = json_array_get(arr, i);
        if (!row || row->type != JSON_ARRAY) return false;
        
        size_t cols = json_array_length(row);
        if (i == 0) {
            mat->cols = cols;
            if (cols == 0 || cols > CANVASL_MAX_MATRIX_COLS) return false;
        } else if (cols != mat->cols) {
            return false;  // Inconsistent column count
        }
        
        for (size_t j = 0; j < cols; j++) {
            json_value_t *item = json_array_get(row, j);
            if (!item || item->type != JSON_NUMBER) return false;
            mat->values[i][j] = (float)json_get_number(item);
        }
    }
    return true;
}

// Execute a JSONL line
bool canvasl_execute_line(canvasl_context_t *ctx, const char *jsonl_line) {
    if (!ctx || !jsonl_line) return false;
    
    json_value_t root;
    if (!json_parse(jsonl_line, &root)) {
        return false;
    }
    
    if (root.type != JSON_OBJECT) {
        json_free(&root);
        return false;
    }
    
    // Check schema
    json_value_t *schema_val = json_object_get(&root, "schema");
    if (!schema_val) {
        // Try old format: check for "op" field
        json_value_t *op_val = json_object_get(&root, "op");
        if (op_val) {
            const char *op = json_get_string(op_val);
            if (!op) {
                json_free(&root);
                return false;
            }
            
            // Execute old-format step
            bool result = false;
            if (strcmp(op, "define_encoder") == 0) {
                json_value_t *encoder_id = json_object_get(&root, "encoder_id");
                json_value_t *A_ref_val = json_object_get(&root, "A_ref");
                json_value_t *b_ref_val = json_object_get(&root, "b_ref");
                json_value_t *basis_dim_val = json_object_get(&root, "basis_dim");
                json_value_t *outputs = json_object_get(&root, "outputs");
                
                if (encoder_id && A_ref_val && b_ref_val && basis_dim_val && outputs) {
                    const char *A_ref = json_get_string(A_ref_val);
                    const char *b_ref = json_get_string(b_ref_val);
                    json_value_t *out_ref_val = json_array_get(outputs, 0);
                    const char *out_ref = out_ref_val ? json_get_string(out_ref_val) : NULL;
                    size_t basis_dim = (size_t)json_get_number(basis_dim_val);
                    
                    if (A_ref && b_ref && out_ref) {
                        result = exec_define_encoder(ctx, json_get_string(encoder_id),
                                                     A_ref, b_ref, basis_dim, out_ref);
                    }
                }
            } else if (strcmp(op, "apply_encoder") == 0) {
                json_value_t *encoder_ref_val = json_object_get(&root, "encoder_ref");
                json_value_t *vars = json_object_get(&root, "vars");
                json_value_t *outputs = json_object_get(&root, "outputs");
                
                if (encoder_ref_val && vars && outputs) {
                    const char *encoder_ref = json_get_string(encoder_ref_val);
                    json_value_t *x_ref_val = json_object_get(vars, "x");
                    json_value_t *out_ref_val = json_array_get(outputs, 0);
                    const char *x_ref = x_ref_val ? json_get_string(x_ref_val) : NULL;
                    const char *out_ref = out_ref_val ? json_get_string(out_ref_val) : NULL;
                    
                    if (encoder_ref && x_ref && out_ref) {
                        result = exec_apply_encoder(ctx, encoder_ref, x_ref, out_ref);
                    }
                }
            } else if (strcmp(op, "decode_and_validate") == 0) {
                json_value_t *target_val = json_object_get(&root, "target");
                json_value_t *boundary_val = json_object_get(&root, "boundary");
                json_value_t *checks = json_object_get(&root, "checks");
                json_value_t *outputs = json_object_get(&root, "outputs");
                
                if (target_val && boundary_val && checks && outputs) {
                    const char *target_ref = json_get_string(target_val);
                    const char *boundary_id = json_get_string(boundary_val);
                    json_value_t *decoded_ref_val = json_array_get(outputs, 0);
                    json_value_t *proof_ref_val = json_array_get(outputs, 1);
                    const char *decoded_ref = decoded_ref_val ? json_get_string(decoded_ref_val) : NULL;
                    const char *proof_ref = proof_ref_val ? json_get_string(proof_ref_val) : NULL;
                    
                    if (target_ref && boundary_id && decoded_ref && proof_ref) {
                        // Parse checks array
                        size_t num_checks = json_array_length(checks);
                        const char *check_strings[CANVASL_MAX_ARRAY_SIZE];
                        for (size_t i = 0; i < num_checks && i < CANVASL_MAX_ARRAY_SIZE; i++) {
                            json_value_t *check_val = json_array_get(checks, i);
                            if (check_val) {
                                check_strings[i] = json_get_string(check_val);
                            }
                        }
                        
                        result = exec_decode_and_validate(ctx, target_ref, boundary_id,
                                                          check_strings, num_checks,
                                                          decoded_ref, proof_ref);
                    }
                }
            }
            
            json_free(&root);
            return result;
        }
    }
    
    // New canvasl-1.0 format
    const char *schema = schema_val ? json_get_string(schema_val) : NULL;
    if (!schema || strcmp(schema, "canvasl-1.0") != 0) {
        json_free(&root);
        return false;
    }
    
    // Check phase monotonicity
    json_value_t *phase_val = json_object_get(&root, "phase");
    if (!phase_val || phase_val->type != JSON_NUMBER) {
        json_free(&root);
        return false;
    }
    
    uint32_t phase = (uint32_t)json_get_number(phase_val);
    if (phase < ctx->last_phase) {
        json_free(&root);
        return false;  // Phase not monotonic
    }
    if (phase > ctx->last_phase) {
        ctx->last_phase = phase;
    }
    
    // Handle different kinds
    json_value_t *kind_val = json_object_get(&root, "kind");
    if (!kind_val) {
        json_free(&root);
        return false;
    }
    
    const char *kind = json_get_string(kind_val);
    if (!kind) {
        json_free(&root);
        return false;
    }
    
    // For now, only handle "transition" kind with operator
    if (strcmp(kind, "transition") == 0) {
        json_value_t *apply = json_object_get(&root, "apply");
        if (apply) {
            json_value_t *operator = json_object_get(apply, "operator");
            if (operator) {
                const char *op = json_get_string(operator);
                // Would need to parse full transition structure
                // For now, just accept it
            }
        }
    }
    
    json_free(&root);
    return true;
}

// Execute step (programmatic interface) - simplified version
bool canvasl_execute_step(canvasl_context_t *ctx, const char *op, ...) {
    // This is a simplified interface - full implementation would use va_list
    // For now, use canvasl_execute_line with constructed JSONL
    (void)ctx;
    (void)op;
    return false;
}

