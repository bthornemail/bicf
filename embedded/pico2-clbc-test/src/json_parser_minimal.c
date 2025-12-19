#include "json_parser_minimal.h"
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

// Simple JSON parser - only handles what we need for CanvasL
// This is NOT a full JSON parser, just enough for CanvasL fields

static void skip_whitespace(const char **p) {
    while (**p && isspace((unsigned char)**p)) {
        (*p)++;
    }
}

static bool parse_string(const char **p, char *out, size_t max_len) {
    if (**p != '"') return false;
    (*p)++;
    
    size_t i = 0;
    while (**p && **p != '"' && i < max_len - 1) {
        if (**p == '\\') {
            (*p)++;
            if (**p == 'n') {
                out[i++] = '\n';
            } else if (**p == 't') {
                out[i++] = '\t';
            } else if (**p == 'r') {
                out[i++] = '\r';
            } else if (**p == '\\' || **p == '"') {
                out[i++] = **p;
            } else {
                out[i++] = **p;  // Simple escape handling
            }
            (*p)++;
        } else {
            out[i++] = **p;
            (*p)++;
        }
    }
    out[i] = '\0';
    
    if (**p == '"') {
        (*p)++;
        return true;
    }
    return false;
}

static bool parse_number(const char **p, double *out) {
    char *end;
    *out = strtod(*p, &end);
    if (end == *p) return false;
    *p = end;
    return true;
}

static bool parse_value(const char **p, json_value_t *val);

static bool parse_array(const char **p, json_value_t *val) {
    if (**p != '[') return false;
    (*p)++;
    skip_whitespace(p);
    
    val->type = JSON_ARRAY;
    val->data.array_val.count = 0;
    
    if (**p == ']') {
        (*p)++;
        return true;
    }
    
    while (**p && val->data.array_val.count < JSON_MAX_ARRAY_SIZE) {
        json_value_t *item = &val->data.array_val.items[val->data.array_val.count];
        if (!parse_value(p, item)) {
            return false;
        }
        val->data.array_val.count++;
        
        skip_whitespace(p);
        if (**p == ']') {
            (*p)++;
            return true;
        }
        if (**p != ',') return false;
        (*p)++;
        skip_whitespace(p);
    }
    
    return false;  // Array too large or malformed
}

static bool parse_object(const char **p, json_value_t *val) {
    if (**p != '{') return false;
    (*p)++;
    skip_whitespace(p);
    
    val->type = JSON_OBJECT;
    val->data.object_val.count = 0;
    
    if (**p == '}') {
        (*p)++;
        return true;
    }
    
    while (**p && val->data.object_val.count < JSON_MAX_ARRAY_SIZE) {
        json_object_pair_t *pair = &val->data.object_val.pairs[val->data.object_val.count];
        
        // Parse key
        if (!parse_string(p, pair->key, JSON_MAX_STRING_LEN)) {
            return false;
        }
        
        skip_whitespace(p);
        if (**p != ':') return false;
        (*p)++;
        skip_whitespace(p);
        
        // Parse value directly into pair (simplified - no deep nesting)
        // For CanvasL, we only need shallow object access
        json_value_t *value = &pair->value_storage;
        if (!parse_value(p, value)) {
            return false;
        }
        pair->value = value;
        
        val->data.object_val.count++;
        
        skip_whitespace(p);
        if (**p == '}') {
            (*p)++;
            return true;
        }
        if (**p != ',') return false;
        (*p)++;
        skip_whitespace(p);
    }
    
    return false;  // Object too large or malformed
}

static bool parse_value(const char **p, json_value_t *val) {
    skip_whitespace(p);
    
    if (**p == '"') {
        val->type = JSON_STRING;
        return parse_string(p, val->data.string_val, JSON_MAX_STRING_LEN);
    } else if (**p == '{') {
        return parse_object(p, val);
    } else if (**p == '[') {
        return parse_array(p, val);
    } else if (strncmp(*p, "true", 4) == 0) {
        val->type = JSON_BOOL;
        val->data.bool_val = true;
        *p += 4;
        return true;
    } else if (strncmp(*p, "false", 5) == 0) {
        val->type = JSON_BOOL;
        val->data.bool_val = false;
        *p += 5;
        return true;
    } else if (strncmp(*p, "null", 4) == 0) {
        val->type = JSON_NULL;
        *p += 4;
        return true;
    } else if (isdigit((unsigned char)**p) || **p == '-' || **p == '+') {
        val->type = JSON_NUMBER;
        return parse_number(p, &val->data.number_val);
    }
    
    return false;
}

bool json_parse(const char *json_str, json_value_t *out) {
    if (!json_str || !out) return false;
    const char *p = json_str;
    return parse_value(&p, out);
}

json_value_t *json_object_get(json_value_t *obj, const char *key) {
    if (!obj || obj->type != JSON_OBJECT || !key) return NULL;
    
    for (size_t i = 0; i < obj->data.object_val.count; i++) {
        if (strcmp(obj->data.object_val.pairs[i].key, key) == 0) {
            return obj->data.object_val.pairs[i].value;
        }
    }
    return NULL;
}

const char *json_get_string(json_value_t *val) {
    if (!val || val->type != JSON_STRING) return NULL;
    return val->data.string_val;
}

double json_get_number(json_value_t *val) {
    if (!val || val->type != JSON_NUMBER) return 0.0;
    return val->data.number_val;
}

bool json_get_bool(json_value_t *val) {
    if (!val || val->type != JSON_BOOL) return false;
    return val->data.bool_val;
}

json_value_t *json_array_get(json_value_t *arr, size_t index) {
    if (!arr || arr->type != JSON_ARRAY || index >= arr->data.array_val.count) {
        return NULL;
    }
    return arr->data.array_val.items[index];
}

size_t json_array_length(json_value_t *arr) {
    if (!arr || arr->type != JSON_ARRAY) return 0;
    return arr->data.array_val.count;
}

void json_free(json_value_t *val) {
    // For static storage, just reset (no actual free needed)
    (void)val;
    // In a full implementation with dynamic allocation, would free here
}

