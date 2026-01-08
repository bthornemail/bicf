# CAN-ISA Evolution: From CLBC to Tetragrammatron-OS

**Version:** 1.0.0
**Last Updated:** 2025-12-20

This document provides a technical deep-dive into the evolution of the CAN-ISA (Canonical Algebraic Normal Instruction Set Architecture) from the production CLBC system through the MVP implementation to the formal Tetragrammatron-OS specification.

---

## Table of Contents

1. [The Clean Break Philosophy](#the-clean-break-philosophy)
2. [CLBC Technical Overview](#clbc-technical-overview)
3. [CAN-ISA MVP Technical Overview](#can-isa-mvp-technical-overview)
4. [Tetragrammatron-OS Technical Overview](#tetragrammatron-os-technical-overview)
5. [Artifact Format Evolution](#artifact-format-evolution)
6. [Bytecode Evolution](#bytecode-evolution)
7. [State Model Evolution](#state-model-evolution)
8. [Hardware Implementation Evolution](#hardware-implementation-evolution)
9. [Migration Paths](#migration-paths)
10. [Performance Characteristics](#performance-characteristics)

---

## The Clean Break Philosophy

### Why Not Incremental Evolution?

The transition from CLBC → CAN-ISA MVP → Tetragrammatron-OS represents **clean architectural breaks** rather than incremental versions. This design philosophy prioritizes:

**1. Conceptual Clarity**
- Each system has a single, well-defined purpose
- No accumulated technical debt from backward compatibility
- Clean separation of concerns

**2. Formal Verification**
- Each system can be proven correct independently
- No hidden assumptions from previous versions
- Explicit invariants at each level

**3. Experimental Freedom**
- CAN-ISA MVP can validate minimal semantics
- Tetragrammatron-OS can explore RFC-driven formalization
- BICF can continue production evolution

**4. Shared Foundations**
- All systems build on Fano geometry
- Common polynomial algebra primitives
- Shared hardware targets

### The Three Tracks

```
BICF Production Track:
├─ Stable production system
├─ Comprehensive features
└─ Continuous refinement

CAN-ISA MVP Track:
├─ Minimal polynomial semantics
├─ Field testing platform
└─ Proof of concept

Tetragrammatron-OS Track:
├─ RFC-driven formalization
├─ Proof-carrying computation
└─ Research platform

All tracks share:
├─ Fano plane (PG(2,2))
├─ Deterministic execution
├─ Polynomial algebra
└─ Embedded hardware (ESP32, Pico)
```

---

## CLBC Technical Overview

**CLBC (CanvasL Bytecode Container)** is the production bytecode format for the BICF system.

### File Paths
- **Compiler**: `src/clbc/compiler.scm`
- **VM**: `src/vm/clbc-vm.scm`
- **CanvasL Interpreter**: `src/canvasl/interpreter.scm`
- **Embedded ESP32**: `embedded/esp32-mqtt-clbc/`
- **Embedded Pico 2W**: `embedded/pico2w-mqtt-clbc/`

### Architecture

**Container Format**:
```
┌─────────────────────────────────┐
│ Magic: "CLBC\0" (5 bytes)      │
├─────────────────────────────────┤
│ Version: u8                     │
├─────────────────────────────────┤
│ Record Stream:                  │
│   - Boundary Records            │
│   - Ticket Records              │
│   - Guarantee Records           │
│   - Environment Bindings        │
└─────────────────────────────────┘
```

**Record Stream Bytecode**: Variable-length records encoding CanvasL operations

**State Representation**: Environment as association list (alist)
```scheme
; Environment structure
((key1 . value1)
 (key2 . value2)
 (key3 . value3))
```

### Execution Model

**Sequential Record Processing**:
1. **Load**: Parse `.clbc` container, extract records
2. **Phase Ordering**: Process records in phase order (Boundary → Ticket → Guarantee)
3. **Operation Execution**:
   - `define_encoder`: Create encoder object
   - `apply_encoder`: Compute `A*x + b` transformations
   - `decode_and_validate`: Decode and validate against FANO/PCG
4. **Validation**: FANO incidence and PCG pair-cover checks
5. **Environment Update**: Update environment bindings
6. **Transcript**: Deterministic execution trace

### CanvasL JSONL Integration

CLBC bytecode is compiled from **CanvasL JSONL** records:

```json
{
  "id": "step-1",
  "phase": 1,
  "boundary": "FANO-v1",
  "op": "apply_encoder",
  "encoder_ref": "enc:E.local.1",
  "vars": {"x": "ref:state_vector:t1"},
  "inputs": ["enc:E.local.1", "ref:state_vector:t1"],
  "outputs": ["state:encoded:t1"]
}
```

**Compilation Flow**:
```
CanvasL JSONL → CLBC Compiler → .clbc Container → CLBC VM → Transcript
```

### Production Status

**Deployed**: Yes
**Use Cases**:
- Production CanvasL execution
- Native Repository Runtime (NRR) integration
- Distributed deterministic computation
- Docker orchestration

**Features**:
- ✅ Full FANO/PCG validation
- ✅ Phase-ordered execution
- ✅ Environment management
- ✅ Error handling and logging
- ✅ Docker deployment
- ✅ ESP32/Pico hardware support

**Documentation**: 8 production documents in `production-docs/`

---

## CAN-ISA MVP Technical Overview

**CAN-ISA MVP** is a minimal polynomial virtual machine validating univariate F₂[x] canonical state representation.

### File Paths
- **Implementation**: `embedded/canisa-mvp/canisa_mvp.{c,h}`
- **Polynomial Backend**: `embedded/canisa-mvp/canisa_poly_f2.{c,h}`
- **SHA-256**: `embedded/canisa-mvp/sha256.{c,h}`
- **Assembler**: `tools/can-asm.scm`
- **Runner**: `tools/can-run.scm`
- **Documentation**: `docs/canisa-mvp.md`

### Architecture

**Container Format**:
```
┌─────────────────────────────────┐
│ Magic: "CANBC\0" (6 bytes)     │
├─────────────────────────────────┤
│ Version: u16le                  │
├─────────────────────────────────┤
│ Payload Length: u32le           │
├─────────────────────────────────┤
│ Payload: CAN-ISA Bytecode       │
│   (variable-length, 1-3 bytes)  │
└─────────────────────────────────┘
```

**State Representation**: Univariate F₂[x] polynomial
```c
// Polynomial represented as coefficient list
// Example: x³ + x² + 1 = [1, 0, 1, 1] (little-endian)
typedef struct {
    bool* coeffs;     // Coefficient array
    size_t degree;    // Polynomial degree
} Poly_F2;
```

### Opcode Set (16 Minimal Operations)

**Polynomial Operations**:
- `STATE_ADD`: Polynomial XOR (addition in F₂[x])
- `STATE_GCD`: Polynomial greatest common divisor
- `STATE_LCM`: Polynomial least common multiple
- `STATE_NORM`: Canonical trim (remove leading zeros)
- `STATE_HASH`: SHA-256(u16le(len) || coeff-bytes)

**Handle Management**:
- `TERM_NEW`: Create new polynomial handle
- `TERM_FREE`: Free polynomial handle

**Control Flow**:
- `HALT`: Stop execution

**State Queries**:
- `STATE_DEG`: Get polynomial degree
- `STATE_COEFF`: Get coefficient at index

**Bytecode Encoding**: Variable-length (1-3 bytes per instruction)
```
Opcode byte: 8 bits
Optional operands: 0-2 bytes
```

### Execution Model

**Polynomial Operations Sequence**:
1. **Load**: Parse `.canbc` container
2. **Initialize**: Start with zero polynomial (state = 0)
3. **Execute**: Process bytecode operations sequentially
4. **Operations**:
   - Create polynomial handles (TERM_NEW)
   - Add/GCD/LCM operations
   - Normalize to canonical form (STATE_NORM)
5. **Finalize**: Compute SHA-256 hash of canonical state
6. **Result**: Return hash for cross-platform validation

### Canonical State Hashing

**Hash Computation**:
```c
// Canonical polynomial hash
hash = sha256(u16le(degree + 1) || coeff_bytes)

// Example: x³ + x² + 1 = [1, 0, 1, 1]
// degree = 3, len = 4
// hash = sha256([0x04, 0x00] || [0x01, 0x00, 0x01, 0x01])
```

**Properties**:
- **Deterministic**: Same polynomial → same hash
- **Canonical**: Only one representation per polynomial
- **Cross-platform**: Identical on ESP32, Pico, x86-64

### Polynomial Backend

Uses `src/aal/polynomials.scm` for algebraic operations:

```scheme
; Polynomial operations (proven in Coq)
(poly-add p1 p2)      ; XOR
(poly-mul p1 p2)      ; Multiplication
(poly-gcd p1 p2)      ; GCD
(poly-lcm p1 p2)      ; LCM
(poly-divmod p1 p2)   ; Division with remainder
(trim p)              ; Canonical form
```

**Proven Properties** (from AAL v3.2):
- Associativity, commutativity, identity
- GCD/LCM lattice properties
- Canonical form uniqueness

### MVP Status

**Field Testing**: Yes
**Use Cases**:
- Minimal embedded polynomial computation
- 3-device MQTT cross-platform validation
- CAN-ISA semantics proof-of-concept

**Features**:
- ✅ Univariate F₂[x] state
- ✅ 16 minimal opcodes
- ✅ Deterministic canonical hashing
- ✅ ESP32 MQTT integration
- ⚠️ Pico 2W planned

**Limitations**:
- No multi-variate polynomials
- No explicit PROJ_FANO operator
- No fold axiom opcodes
- No barrier enforcement

**Documentation**: 1 minimal document (`docs/canisa-mvp.md`)

---

## Tetragrammatron-OS Technical Overview

**Tetragrammatron-OS** is a formal, RFC-driven geometry-first operating system with proof-carrying bytecode.

### File Paths
- **Main**: `apps/tetragrammatron-os/`
- **VM Core**: `apps/tetragrammatron-os/vm/can_vm.{c,h}`
- **Codec**: `apps/tetragrammatron-os/vm/can_codec.{c,h}`
- **Container**: `apps/tetragrammatron-os/vm/canb_container.{c,h}`
- **Polynomials**: `apps/tetragrammatron-os/vm/can_poly.{c,h}`
- **Object Pool**: `apps/tetragrammatron-os/vm/can_objpool.{c,h}`
- **Assembler**: `apps/tetragrammatron-os/assembler/scheme/can_asm.scm`
- **RFCs**: `apps/tetragrammatron-os/rfc/RFC-{0000,0009,0011,0012,0013,0017}.md`

### Architecture

**Container Format** (CANB v1, RFC-0012):
```
┌─────────────────────────────────┐
│ Magic: "CANB\0" (5 bytes)      │
├─────────────────────────────────┤
│ Version: u8 (currently 1)       │
├─────────────────────────────────┤
│ Flags: u8                       │
├─────────────────────────────────┤
│ Entry Point: u32le              │
├─────────────────────────────────┤
│ Code Length: u32le              │
├─────────────────────────────────┤
│ Code: Fixed 32-bit Instructions │
│   (4 bytes per instruction)     │
├─────────────────────────────────┤
│ Data Segment: Variable          │
└─────────────────────────────────┘
```

**Instruction Format**: 32-bit fixed-width (big-endian)
```
┌────────┬────────┬────────┬────────┐
│ Opcode │  Reg A │  Reg B │ Reg C  │
│ [31:24]│ [23:16]│ [15:8] │ [7:0]  │
└────────┴────────┴────────┴────────┘

Alternative interpretations:
- Immediate: [15:0] as 16-bit immediate
- Address: [23:0] as 24-bit address
```

**State Representation**: 8-tuple semantic registers
```c
typedef struct {
    Object* state;      // What exists
    Object* symbol;     // What is referenced
    Object* left;       // Structural/static projection
    Object* right;      // Experiential/dynamic projection
    Object* transition; // Change
    Object* source;     // Origin
    Object* target;     // Destination
    Object* result;     // Outcome
} VM;
```

### Opcode Set (~25 Operations with Fold Semantics)

**Polynomial Lattice Operations** (RFC-0009):
- `CANON r`: Normalize register to canonical form
- `MEET_GCD ra rb rc`: rc = GCD(ra, rb) (meet in lattice)
- `JOIN_LCM ra rb rc`: rc = LCM(ra, rb) (join in lattice)
- `COPY ra rb`: rb = ra
- `SWAP ra rb`: Exchange ra ↔ rb

**Geometry Operations** (RFC-0009, RFC-0017):
- `PROJ_FANO r`: Idempotent Fano plane projection
- `EMIT_NODE r`: Emit geometry node
- `EMIT_EDGE ra rb`: Emit geometry edge
- `LIFT_3D r`: Lift to 3D mesh coordinates

**State Management** (RFC-0009):
- `COMMIT_HASH r`: Compute state commitment hash
- `LOAD_STATE r`: Load state into register
- `STORE_STATE r`: Store register to state

**Assertions** (RFC-0000):
- `ASSERT_CANON r`: Assert register is canonical
- `ASSERT_IDEMP r`: Assert idempotent property
- `ASSERT_FANO r`: Assert Fano plane invariant

**Time Operations** (RFC-0013):
- `TIME_RD r platform`: Read platform time source
- `TIME_DIV ra rb rc`: Time division/scheduling
- `WAIT r`: Wait until time condition
- `BARRIER_T`: Time barrier (synchronization point)

**Control Flow**:
- `HALT`: Stop execution
- `JUMP addr`: Unconditional jump
- `BRANCH_ZERO r addr`: Conditional branch

**Object Pool**:
- `ALLOC r size`: Allocate object
- `FREE r`: Free object
- `REFCNT r`: Get reference count

### Execution Model

**Fold Semantics (RFC-0009)**:

Every instruction is a **fold** (idempotent reduction):
1. **Idempotence**: fold(fold(x)) = fold(x)
2. **Ordering Independence**: fold(a, b) = fold(b, a) when commutative
3. **Associativity**: fold(fold(a, b), c) = fold(a, fold(b, c))
4. **Bounded**: Finite lattice ensures termination

**Execution Sequence**:
1. **Load**: Parse `.canb` container (CANB v1)
2. **Initialize**: Setup 8-tuple semantic registers
3. **Execute**: Process 32-bit instructions from entry point
4. **Fold Operations**:
   - Polynomial lattice operations (CANON, MEET_GCD, JOIN_LCM)
   - Geometry projections (PROJ_FANO, EMIT_NODE, LIFT_3D)
   - State commitments (COMMIT_HASH)
5. **Validation**: Assert invariants (ASSERT_CANON, ASSERT_IDEMP, ASSERT_FANO)
6. **Barriers**: Enforce time barriers (BARRIER_T, WAIT)
7. **Result**: Return result register

### RFC-Driven Formalization

**6 Normative RFCs**:

1. **RFC-0000**: CAN-ISA Invariants
   - 20 invariants for VM correctness
   - Idempotence, canonicality, determinism
   - Fano plane structural properties

2. **RFC-0009**: Origami Fold VM
   - Fold semantics definition
   - 8-tuple register model
   - Polynomial lattice operations
   - Geometry projection operators

3. **RFC-0011**: Repository Lattice
   - 8³ semantic topology
   - Fano merge gate
   - Conflict-free merge semantics

4. **RFC-0012**: Binary Encoding (CANB v1)
   - 32-bit fixed-width instruction format
   - Container structure
   - Endianness and alignment

5. **RFC-0013**: Time and Barriers
   - Platform time sources
   - Barrier enforcement
   - Scheduling semantics

6. **RFC-0017**: LIFT_3D Mesh Semantics
   - 3D geometry emission
   - Mesh anchor coordinates
   - SVG/GLB rendering

### Lean Formal Verification

**20 Invariants** (specified in `proof/RFC0012_FoldVM.lean`):

**Structural Invariants**:
- Register type soundness
- Object pool consistency
- Memory safety

**Semantic Invariants**:
- Idempotence of CANON
- Commutativity of MEET_GCD/JOIN_LCM
- PROJ_FANO projection property
- COMMIT_HASH determinism

**Geometry Invariants**:
- Fano plane incidence preservation
- 7-point structure maintenance
- Line intersection uniqueness

**Status**: Invariants specified, proofs pending full implementation

### Repository Lattice (RFC-0011)

**8³ Topology**: 512-node semantic lattice

**8 Axes**:
- `state/` - What exists
- `symbol/` - What is referenced
- `left/` - Structural projection
- `right/` - Experiential projection
- `transition/` - Change
- `source/` - Origin
- `target/` - Destination
- `result/` - Outcome

**Fano Merge Gate**: Conflict-free merges using Fano incidence structure

**File Structure**:
```
apps/tetragrammatron-os/repo.canvasl/
├── kernel.canvasl
├── triads/
│   ├── fano_l0.canvasl
│   ├── fano_l1.canvasl
│   └── ...
├── state/
├── symbol/
├── left/
├── right/
├── transition/
├── source/
├── target/
└── result/
```

### Tetragrammatron-OS Status

**Research-Grade**: Active development

**What's Complete**:
- ✅ 6 normative RFCs
- ✅ VM core structure (~3,387 lines C)
- ✅ CANB v1 codec
- ✅ Assembler (Scheme)
- ✅ Repository lattice
- ✅ Geometry rendering (SVG)
- ✅ 20 Lean invariants (specified)

**What's Stubbed**:
- ⚠️ Polynomial operations (CANON, MEET_GCD, JOIN_LCM)
- ⚠️ Fano projection (PROJ_FANO)
- ⚠️ Assertions (ASSERT_CANON, ASSERT_IDEMP, ASSERT_FANO)
- ⚠️ Time operations (TIME_RD, TIME_DIV, WAIT, BARRIER_T)
- ⚠️ Commit hash (COMMIT_HASH)
- ⚠️ Geometry emission (EMIT_NODE, EMIT_EDGE, LIFT_3D)
- ⚠️ Hardware integration (ESP32/Pico firmware)

**Documentation**: README, 6 RFCs, 40+ dev docs

---

## Artifact Format Evolution

### Container Magic Evolution

```
CLBC:   "CLBC\0" (5 bytes) - Production CanvasL bytecode
CANBC:  "CANBC\0" (6 bytes) - CAN-ISA MVP polynomial bytecode
CANB:   "CANB\0" (5 bytes) - Tetragrammatron-OS formal bytecode
```

### Format Comparison

| Feature | .clbc | .canbc | .canb |
|---------|-------|--------|-------|
| **Magic** | CLBC\0 | CANBC\0 | CANB\0 |
| **Magic Size** | 5 bytes | 6 bytes | 5 bytes |
| **Version** | u8 | u16le | u8 |
| **Encoding** | Variable records | Variable bytecode | Fixed 32-bit |
| **Instruction Size** | Variable | 1-3 bytes | 4 bytes (fixed) |
| **Endianness** | N/A (Scheme data) | Little-endian | Big-endian |
| **Entry Point** | Implicit | Implicit | Explicit (u32le) |
| **Code Length** | Implicit | u32le | u32le |
| **Data Segment** | Embedded in records | None | Explicit segment |
| **Alignment** | None | None | 4-byte aligned |

### Detailed Format Specifications

#### .clbc Container
```
Offset  Size    Field
0x00    5       Magic: "CLBC\0"
0x05    1       Version (currently 1)
0x06    var     Record Stream:
                  - Boundary Records
                  - Ticket Records
                  - Guarantee Records
                  - Environment Bindings
```

#### .canbc Container
```
Offset  Size    Field
0x00    6       Magic: "CANBC\0"
0x06    2       Version (u16le, currently 1)
0x08    4       Payload Length (u32le)
0x0C    N       Payload (CAN-ISA bytecode, N bytes)
```

#### .canb Container (CANB v1)
```
Offset  Size    Field
0x00    5       Magic: "CANB\0"
0x05    1       Version (u8, currently 1)
0x06    1       Flags (u8)
0x07    4       Entry Point (u32le)
0x0B    4       Code Length (u32le, in bytes)
0x0F    N       Code Section (N bytes, N % 4 == 0)
N+0x0F  M       Data Section (M bytes, optional)
```

---

## Bytecode Evolution

### Instruction Encoding Comparison

#### CLBC: Variable-Length Records
```scheme
; CanvasL record (Scheme S-expression)
(define-encoder "enc:E.local.1"
  (matrix ((1 0 1) (0 1 1) (1 1 0)))
  (offset (0 0 1)))

; Encoded as variable-length record in .clbc
```

#### CAN-ISA MVP: Variable-Length Opcodes
```
STATE_ADD:      1 byte  (opcode only)
TERM_NEW:       2 bytes (opcode + handle-id)
STATE_GCD:      3 bytes (opcode + src1 + src2)
```

**Example Bytecode**:
```
0x01          ; TERM_NEW (create polynomial handle 1)
0x05 0x01     ; STATE_ADD handle 1
0x02 0x01 0x02; STATE_GCD handle 1, handle 2
0x03          ; STATE_NORM
0x04          ; STATE_HASH
0xFF          ; HALT
```

#### Tetragrammatron-OS: Fixed 32-Bit Instructions
```
Every instruction: 32 bits (4 bytes)

┌────────┬────────┬────────┬────────┐
│ Opcode │  Reg A │  Reg B │ Reg C  │
│   8b   │   8b   │   8b   │   8b   │
└────────┴────────┴────────┴────────┘
```

**Example Bytecode**:
```
0x10 0x00 0x01 0x02  ; MEET_GCD r0 r1 r2 (r2 = GCD(r0, r1))
0x11 0x00 0x01 0x03  ; JOIN_LCM r0 r1 r3 (r3 = LCM(r0, r1))
0x12 0x02 0x00 0x00  ; CANON r2 (normalize r2)
0x20 0x02 0x00 0x00  ; PROJ_FANO r2 (Fano projection)
0x30 0x02 0x00 0x00  ; COMMIT_HASH r2 (hash state)
0xFF 0x00 0x00 0x00  ; HALT
```

### Opcode Count Evolution

| System | Opcode Count | Encoding |
|--------|-------------|----------|
| **CLBC** | ~20 (CanvasL operations) | Variable records |
| **CAN-ISA MVP** | 16 (minimal polynomial ops) | Variable 1-3 bytes |
| **Tetragrammatron-OS** | ~25 (fold semantics + geometry) | Fixed 32-bit |

### Bytecode Density

**CLBC**: Low density (verbose Scheme records, human-readable)
**CAN-ISA MVP**: High density (compact bytecode, minimal overhead)
**Tetragrammatron-OS**: Medium density (fixed 32-bit, predictable size)

**Example Program Size**:
```
Polynomial GCD computation:
- CLBC:      ~200 bytes (CanvasL JSONL)
- CAN-ISA MVP: ~20 bytes (compact bytecode)
- Tetragrammatron-OS: ~24 bytes (6 instructions × 4 bytes)
```

---

## State Model Evolution

### CLBC: Environment as Association List

**Data Structure**:
```scheme
; Environment: alist of key-value pairs
'((key1 . value1)
  (key2 . value2)
  (encoder:E.local.1 . #(matrix offset))
  (state:encoded:t1 . #(vector)))
```

**Operations**:
- Lookup: O(n) linear scan
- Update: O(n) (rebuild alist)
- Immutable: New alist on each update

**State Size**: Unbounded (grows with environment bindings)

---

### CAN-ISA MVP: Single Polynomial

**Data Structure**:
```c
typedef struct {
    bool* coeffs;    // Coefficient array [c0, c1, c2, ...]
    size_t degree;   // Polynomial degree (highest non-zero coefficient)
    size_t capacity; // Allocated capacity
} Poly_F2;

// Global VM state
Poly_F2 vm_state;
```

**Operations**:
- Addition: O(n) XOR of coefficient arrays
- GCD: O(n²) Euclidean algorithm
- LCM: O(n²) via GCD
- Normalization: O(n) trim leading zeros

**State Size**: O(degree) - proportional to polynomial degree

**Canonical Form**: Trimmed (no leading zeros)

---

### Tetragrammatron-OS: 8-Tuple Registers + Object Pool

**Data Structure**:
```c
// 8 semantic registers
typedef struct {
    Object* state;      // Current state
    Object* symbol;     // Symbolic reference
    Object* left;       // Structural projection
    Object* right;      // Experiential projection
    Object* transition; // State change
    Object* source;     // Transformation source
    Object* target;     // Transformation target
    Object* result;     // Operation result
} VM;

// Object pool for memory management
typedef struct {
    Object* objects;    // Pool of allocated objects
    size_t count;       // Number of active objects
    size_t capacity;    // Pool capacity
} ObjectPool;

// Object types
typedef enum {
    OBJ_POLY,          // Polynomial
    OBJ_TRIAD,         // Fano triad
    OBJ_MESH,          // 3D mesh
    OBJ_HASH,          // Hash value
} ObjectType;
```

**Operations**:
- Register access: O(1) direct access
- Object allocation: O(1) from pool
- Polynomial ops: O(n) to O(n²) depending on operation
- Geometry projection: O(1) for Fano (7 points)

**State Size**:
- Fixed: 8 registers × sizeof(Object*)
- Variable: Object pool size (managed)

**Canonical Form**: Each register maintains canonical invariant (enforced by ASSERT_CANON)

---

### State Model Comparison

| Aspect | CLBC | CAN-ISA MVP | Tetragrammatron-OS |
|--------|------|-------------|---------------------|
| **Primary Structure** | Alist | Single Polynomial | 8 Registers |
| **Secondary Storage** | None | Term handles | Object pool |
| **Lookup Complexity** | O(n) | O(1) (direct state) | O(1) (register access) |
| **Update Complexity** | O(n) | O(degree) | O(1) + O(op) |
| **Memory Model** | Immutable | Mutable | Managed pool |
| **Canonical Enforcement** | None (application-level) | NORM opcode | ASSERT_CANON + CANON |
| **State Size** | Unbounded | O(degree) | Fixed + pool |
| **Typical Size** | ~1KB-10KB | ~100 bytes | ~64 bytes + objects |

---

## Hardware Implementation Evolution

### CLBC: ESP32 and Pico 2W with MQTT

**ESP32 Implementation**: `embedded/esp32-mqtt-clbc/`

**Features**:
- WiFi connectivity (ESP-IDF)
- MQTT client (topics: `clbc/<device-id>/cmd`, `clbc/<device-id>/result`)
- CLBC VM integration
- Zero-config discovery (auto-generated device IDs)
- UDP discovery support
- NVS storage for configuration
- OTA firmware updates

**Pico 2W Implementation**: `embedded/pico2w-mqtt-clbc/`

**Features**:
- RP2350 (ARM Cortex-M33) port
- CLBC VM verified cross-architecture
- USB CDC → MQTT bridge (`tools/pico-mqtt-bridge.py`)
- Deterministic replay validation

**Deployment**:
```bash
# Flash ESP32
scripts/flash-esp32-mqtt-clbc.sh /dev/ttyUSB0

# Run Pico bridge
python tools/pico-mqtt-bridge.py --port /dev/ttyACM0 --broker 127.0.0.1
```

---

### CAN-ISA MVP: ESP32 with MQTT

**ESP32 Implementation**: `embedded/canisa-mvp/` (integrated with `embedded/esp32-mqtt-clbc/`)

**Features**:
- Same MQTT infrastructure as CLBC
- Polynomial VM backend (univariate F₂[x])
- 16 minimal opcodes
- Canonical state hashing (SHA-256)
- 3-device heterogeneous testing

**MQTT Protocol**:
```
Topics:
  canbc/<device-id>/cmd     (subscribe)
  canbc/<device-id>/result  (publish)

Commands:
  EXEC <base64-encoded .canbc>
  STATUS
  RESET

Results:
  {"hash": "0x1234abcd...", "status": "ok", "exec_ms": 42}
```

**3-Device Demo**:
```bash
# Auto-discovery (zero-config)
scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --auto

# UDP discovery (no MQTT announce)
scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --udp

# Benchmark 25 runs
scripts/bench-canbc-3esp.sh --broker 127.0.0.1 --runs 25
```

**Pico 2W**: Planned (similar architecture)

---

### Tetragrammatron-OS: ESP32 UART Bridge

**ESP32 Implementation**: `apps/tetragrammatron-os/hardware/esp32/can_app/`

**Current Status**: UART bridge to VM

**Features** (planned):
- UART communication with VM
- NVS storage for .canb programs
- WiFi transport (MQTT or custom protocol)
- Time synchronization (for BARRIER_T)
- OTA updates

**Architecture**:
```
┌──────────────────────┐
│   ESP32 Firmware     │
│  ┌────────────────┐  │
│  │ UART Bridge    │  │
│  └────────────────┘  │
│  ┌────────────────┐  │
│  │ NVS Storage    │  │
│  └────────────────┘  │
│  ┌────────────────┐  │
│  │ WiFi Transport │  │
│  └────────────────┘  │
└──────────────────────┘
         ↕ UART
┌──────────────────────┐
│   VM (can_vm.c)      │
│  ┌────────────────┐  │
│  │ Fold Engine    │  │
│  └────────────────┘  │
│  ┌────────────────┐  │
│  │ Object Pool    │  │
│  └────────────────┘  │
└──────────────────────┘
```

**Deployment** (planned):
```bash
# Flash ESP32
cd apps/tetragrammatron-os
scripts/flash-esp32-can.sh /dev/ttyUSB0

# Upload .canb program
scripts/upload-canb.sh /dev/ttyUSB0 build/fold_min.canb

# Run and get result
scripts/run-canb.sh /dev/ttyUSB0
```

**Pico 2W**: Planned (UART/USB CDC bridge)

**Android Termux**: Supported (native ARM64 compilation)

---

### Cross-Platform Determinism

All three systems validate **deterministic execution across architectures**:

**Test Methodology**:
1. Same program (.clbc / .canbc / .canb)
2. Execute on ESP32 (Xtensa), Pico (ARM Cortex-M33), x86-64
3. Compare transcript/state hashes
4. Matching hashes → proven determinism

**Example** (CAN-ISA MVP):
```bash
$ scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --auto

Device canbc-auto-1 (ESP32-S3): hash=0xabcd1234...
Device canbc-auto-2 (ESP32-C6): hash=0xabcd1234...
Device canbc-auto-3 (ESP32-S3): hash=0xabcd1234...

✅ All hashes match - determinism proven
```

---

## Migration Paths

### CLBC → CAN-ISA MVP

**Difficulty**: High (different execution models)

**Approach**: Manual translation

**Challenges**:
1. **State representation**: Environment alist → single polynomial
2. **Operations**: CanvasL operations → polynomial operations
3. **Validation**: FANO/PCG → implicit in polynomial structure
4. **Semantics**: Record processing → bytecode execution

**Not Recommended**: Different use cases (production vs field testing)

**Alternative**: Run both systems in parallel for different workloads

---

### CAN-ISA MVP → Tetragrammatron-OS

**Difficulty**: Medium (conceptual extension)

**Approach**: Extend polynomial model to 8-tuple

**Migration Strategy**:
1. **State mapping**: Single polynomial → `state` register
2. **Opcodes**: MVP opcodes → Tetragrammatron-OS equivalents
   - `STATE_ADD` → register operations with `state`
   - `STATE_GCD` → `MEET_GCD` on `state` register
   - `STATE_LCM` → `JOIN_LCM` on `state` register
   - `STATE_NORM` → `CANON state`
   - `STATE_HASH` → `COMMIT_HASH state`
3. **Handles**: Term handles → object pool objects
4. **Control flow**: HALT → HALT (same)

**Example Translation**:

**CAN-ISA MVP**:
```
TERM_NEW 1          ; Create polynomial handle 1
STATE_ADD 1         ; Add handle 1 to state
STATE_GCD 1 2       ; GCD of handles 1 and 2
STATE_NORM          ; Normalize state
STATE_HASH          ; Hash state
HALT                ; Stop
```

**Tetragrammatron-OS**:
```
ALLOC state 64      ; Allocate state object
COPY state r0       ; Copy to r0
MEET_GCD r0 r1 r2   ; r2 = GCD(r0, r1)
CANON state         ; Normalize state
COMMIT_HASH state   ; Hash state → result
HALT                ; Stop
```

**Recommendations**:
- Use for research exploring formal extensions
- Not for production (Tetragrammatron-OS is research-grade)

---

### BICF ↔ Tetragrammatron-OS

**Difficulty**: High (parallel tracks)

**Approach**: Shared foundations, different applications

**Shared Components**:
- Polynomial algebra (`src/aal/polynomials.scm`)
- Fano plane geometry
- Deterministic execution principles
- Hardware targets (ESP32, Pico)

**Divergent Components**:
- Execution model (record-stream vs fold semantics)
- State representation (environment vs 8-tuple)
- Maturity (production vs research)

**Recommended Strategy**: Parallel development
- BICF: Continue production features
- Tetragrammatron-OS: Explore formal research
- Share: Polynomial proofs, geometric foundations, hardware infrastructure

**Not Recommended**: Direct migration (different purposes)

---

## Performance Characteristics

### Bytecode Size

**Representative Program**: Polynomial GCD computation

| System | Bytecode Size | Notes |
|--------|--------------|-------|
| **CLBC** | ~200 bytes | Verbose CanvasL JSONL |
| **CAN-ISA MVP** | ~20 bytes | Compact variable-length |
| **Tetragrammatron-OS** | ~24 bytes | 6 × 4-byte fixed |

**Density Winner**: CAN-ISA MVP (minimal opcodes, variable-length)

**Predictability Winner**: Tetragrammatron-OS (fixed 32-bit)

---

### Execution Speed

**Note**: Benchmarks are architecture- and implementation-dependent

**Estimated Relative Performance** (ESP32-S3 @ 240MHz):

| Operation | CLBC | CAN-ISA MVP | Tetragrammatron-OS |
|-----------|------|-------------|---------------------|
| **Record Processing** | 1.0× | N/A | N/A |
| **Polynomial Add** | N/A | 1.0× | 1.2× (overhead from 8-tuple) |
| **Polynomial GCD** | N/A | 1.0× | 1.2× |
| **State Hash** | 0.8× | 1.0× | 1.1× |
| **Full Program** | 1.0× | 2.5× (faster) | 2.0× (faster) |

**Performance Notes**:
- **CLBC**: Scheme interpreter overhead, rich features
- **CAN-ISA MVP**: Minimal C implementation, direct polynomial ops
- **Tetragrammatron-OS**: C implementation with register overhead, stubbed ops

**Current Benchmarks** (CAN-ISA MVP, 3-device MQTT):
```bash
$ scripts/bench-canbc-3esp.sh --broker 127.0.0.1 --runs 25

Average exec_ms: 42ms (ESP32-S3)
Average exec_ms: 38ms (ESP32-C6, slightly faster)
```

---

### Memory Footprint

**ESP32 Flash/RAM Usage**:

| System | Flash | RAM | Notes |
|--------|-------|-----|-------|
| **CLBC** | ~800KB | ~150KB | Includes WiFi/MQTT/VM |
| **CAN-ISA MVP** | ~600KB | ~80KB | Minimal polynomial VM |
| **Tetragrammatron-OS** | ~700KB (estimated) | ~120KB (estimated) | VM + object pool |

**Memory Winner**: CAN-ISA MVP (smallest footprint)

**Feature Winner**: CLBC (comprehensive features justify size)

---

### Scalability

**CLBC**:
- Scales with environment size (unbounded)
- Large programs: 10KB-100KB JSONL
- Execution time: O(records × operations)

**CAN-ISA MVP**:
- Scales with polynomial degree (typically < 100)
- Small programs: 100-1000 bytes
- Execution time: O(operations × degree)

**Tetragrammatron-OS**:
- Scales with object pool size (bounded by configuration)
- Medium programs: 1KB-10KB
- Execution time: O(instructions × op_complexity)

---

## Conclusion

The evolution from CLBC → CAN-ISA MVP → Tetragrammatron-OS represents **three complementary tracks**:

1. **BICF (CLBC)**: Production-ready boundary-interior framework
2. **CAN-ISA MVP**: Minimal polynomial VM for field testing
3. **Tetragrammatron-OS**: RFC-driven formal research platform

All three share **Fano geometry, deterministic execution, and embedded hardware targets**, while diverging in **architecture, maturity, and use cases**.

**Choose BICF** for production deployments.
**Choose CAN-ISA MVP** for minimal embedded polynomial computation.
**Choose Tetragrammatron-OS** for formal research and proof-carrying computation.

For detailed selection guidance, see [System Selection Guide](system-selection-guide.md).

---

**Last Updated**: 2025-12-20
**Maintained By**: BICF Production Team
