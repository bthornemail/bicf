#ifndef JSON_PARSER_MINIMAL_H
#define JSON_PARSER_MINIMAL_H

#include <stdbool.h>
#include <stddef.h>

// Minimal JSON parser for CanvasL JSONL lines
// Only parses the fields we need, not full JSON spec

#define JSON_MAX_STRING_LEN 256
#define JSON_MAX_ARRAY_SIZE 16

typedef enum {
    JSON_NULL,
    JSON_BOOL,
    JSON_NUMBER,
    JSON_STRING,
    JSON_ARRAY,
    JSON_OBJECT
} json_value_type_t;

typedef struct json_value json_value_t;

typedef struct {
    char key[JSON_MAX_STRING_LEN];
    json_value_t *value;
    json_value_t value_storage;  // Inline storage to avoid malloc
} json_object_pair_t;

typedef struct json_value {
    json_value_type_t type;
    union {
        bool bool_val;
        double number_val;
        char string_val[JSON_MAX_STRING_LEN];
        struct {
            json_value_t *items[JSON_MAX_ARRAY_SIZE];
            size_t count;
        } array_val;
        struct {
            json_object_pair_t pairs[JSON_MAX_ARRAY_SIZE];
            size_t count;
        } object_val;
    } data;
} json_value_t;

// Parse JSON string into json_value_t
// Returns true on success, false on error
bool json_parse(const char *json_str, json_value_t *out);

// Get value from object by key
json_value_t *json_object_get(json_value_t *obj, const char *key);

// Get string value (returns NULL if not string type)
const char *json_get_string(json_value_t *val);

// Get number value (returns 0.0 if not number type)
double json_get_number(json_value_t *val);

// Get bool value (returns false if not bool type)
bool json_get_bool(json_value_t *val);

// Get array element by index
json_value_t *json_array_get(json_value_t *arr, size_t index);

// Get array length
size_t json_array_length(json_value_t *arr);

// Free parsed JSON value (if dynamically allocated)
void json_free(json_value_t *val);

#endif  // JSON_PARSER_MINIMAL_H

