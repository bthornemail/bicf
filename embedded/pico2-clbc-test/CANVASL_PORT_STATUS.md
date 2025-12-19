# CanvasL Port Status for Pico 2 / Pico 2 W (experimental)

## Completed

1. **Header and structure** (`canvasl_pico.h`):
   - Data types: vectors, matrices, encoders
   - Environment management structure
   - CanvasL context with NRR integration

2. **Core data structures** (`canvasl_pico.c`):
   - Environment get/set operations for vectors, matrices, encoders
   - Linear algebra operations:
     - Matrix-vector multiplication (`canvasl_mat_vec_mul`)
     - Vector addition (`canvasl_vec_add`)

3. **Step execution framework**:
   - Structure for `define_encoder`, `apply_encoder`, `decode_and_validate`
   - Placeholder validation functions (FANO, PCG)

## Remaining Work

### High Priority

1. **JSONL Parser** ✅ COMPLETE:
   - ✅ Minimal JSON parser implemented (`json_parser_minimal.c`)
   - ✅ Parses CanvasL JSONL format (supports both old and new formats)
   - ✅ Extracts operation fields (op, inputs, outputs, etc.)
   - ✅ Handles objects, arrays, strings, numbers, booleans
   - ⚠️ Limited nesting depth (sufficient for CanvasL)

2. **Step Execution Implementation** ✅ MOSTLY COMPLETE:
   - ✅ `exec_define_encoder()` - Complete with parameter parsing
   - ✅ `exec_apply_encoder()` - Complete with full affine transformation
   - ✅ `exec_decode_and_validate()` - Complete with validation framework
   - ✅ Phase monotonicity checking implemented
   - ⚠️ Forward reference checking - Needs environment lookup validation
   - ✅ NRR integration for logging validation results

3. **Validation Functions** ⚠️ PLACEHOLDERS:
   - ⚠️ FANO incidence checking - Placeholder (returns true)
   - ⚠️ PCG pair-cover checking - Placeholder (returns true)
   - **TODO**: Port actual validation logic from Scheme implementations

### Medium Priority

4. **Boundary Registry**:
   - Store and retrieve boundary definitions
   - Support boundary ID matching
   - Support automorphism selection

5. **NRR Integration**:
   - Store encoder definitions in NRR
   - Store validation results in NRR log
   - Enable deterministic replay from NRR log

6. **Error Handling**:
   - Comprehensive error reporting
   - Memory overflow detection
   - Validation failure reporting

### Low Priority

7. **Performance Optimization**:
   - Optimize matrix operations for small dimensions
   - Reduce memory allocations
   - Cache frequently accessed values

8. **Testing**:
   - Unit tests for linear algebra operations
   - Integration tests with JSONL input
   - Parity tests against Scheme implementation

## Memory Constraints

Current limits (configurable in `canvasl_pico.h`):
- Max vector size: 16 elements
- Max matrix: 16x16
- Max environment entries: 32
- Max JSONL line: 512 bytes

These can be adjusted based on available RAM (Pico 2 class boards have ~520KB SRAM).

## Integration Path

1. **Phase 1**: Complete JSONL parsing and basic step execution
2. **Phase 2**: Add FANO/PCG validation
3. **Phase 3**: Integrate with NRR for storage and logging
4. **Phase 4**: Add deterministic replay from NRR log
5. **Phase 5**: Validate parity with ESP32 and desktop implementations

## Next Steps

To complete the CanvasL port:

1. ✅ ~~Choose JSON parsing approach~~ - Minimal parser implemented
2. ✅ ~~Implement full step execution~~ - Core operations complete
3. ⏳ **Port FANO/PCG validation logic** - Critical for deterministic validation
4. ⏳ Add forward reference checking (validate inputs exist in environment)
5. ⏳ Add comprehensive testing
6. ⏳ Validate deterministic replay matches Scheme implementation

## Current Capabilities

The CanvasL port can now:
- ✅ Parse JSONL lines (both old format with "op" and new "canvasl-1.0" format)
- ✅ Execute `define_encoder` operations (affine encoders)
- ✅ Execute `apply_encoder` operations (A*x + b transformations)
- ✅ Execute `decode_and_validate` operations (with placeholder validators)
- ✅ Maintain phase monotonicity
- ✅ Store results in environment
- ✅ Log operations to NRR

**Limitation**: FANO and PCG validation currently always return true. These need to be ported from the Scheme implementations to be fully functional.
