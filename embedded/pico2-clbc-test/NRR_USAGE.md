# NRR (Native Repository Runtime) for Pico W2

## Overview

NRR provides content-addressed storage and append-only log functionality for Pico W2. This is a memory-constrained implementation suitable for embedded systems.

## Features

- **Content-addressed storage**: Store content by SHA-256 hash reference
- **Append-only log**: Deterministic log entries for replay
- **Memory-efficient**: In-memory storage with configurable limits
- **Deduplication**: Automatic content deduplication by hash

## API

### Initialization

```c
#include "nrr_pico.h"

nrr_context_t ctx;
nrr_init(&ctx);
```

### Store Content

```c
uint8_t content[] = "Hello, World!";
char ref[NRR_REF_STRING_SIZE];
if (nrr_put(&ctx, content, sizeof(content) - 1, ref)) {
    printf("Stored with ref: %s\n", ref);
}
```

### Retrieve Content

```c
uint8_t content_out[NRR_MAX_CONTENT_SIZE];
size_t len = nrr_get(&ctx, ref, content_out, sizeof(content_out));
if (len > 0) {
    printf("Retrieved %zu bytes\n", len);
}
```

### Append Log Entry

```c
if (nrr_append(&ctx, 0, NRR_LOG_BOUNDARY, ref)) {
    printf("Log entry appended\n");
}
```

### Retrieve Log Entries

```c
nrr_log_entry_t entries[NRR_MAX_ENTRIES];
size_t count = nrr_log(&ctx, entries, NRR_MAX_ENTRIES);
for (size_t i = 0; i < count; i++) {
    printf("Phase %u, Type %d, Ref: %s\n", 
           entries[i].phase, entries[i].type, entries[i].ref);
}
```

## Memory Limits

- **Max content size**: 4096 bytes (configurable via `NRR_MAX_CONTENT_SIZE`)
- **Max storage entries**: 64 (configurable via `NRR_MAX_ENTRIES`)
- **Max log entries**: 64 (configurable via `NRR_MAX_ENTRIES`)

Adjust these limits in `nrr_pico.h` based on available RAM.

## Reference Format

References are SHA-256 hashes formatted as:
```
nrr:<64-hex-characters>
```

Example: `nrr:b00758344445a0297a1cd4fcecb5b35e692c4013b95d51e304b8741133b75abe`

## Integration with CLBC VM

The NRR can be used to store CLBC program bytes and log execution events:

```c
// Store CLBC program
char program_ref[NRR_REF_STRING_SIZE];
nrr_put(&ctx, clbc_bytes, clbc_len, program_ref);

// Log execution
nrr_append(&ctx, phase, NRR_LOG_BOUNDARY, program_ref);
```

## Deterministic Replay

The append-only log enables deterministic replay:

1. Store all inputs via `nrr_put()`
2. Log all events via `nrr_append()`
3. Replay by iterating log entries and retrieving content via `nrr_get()`

This matches the Scheme NRR interface for cross-platform compatibility.

