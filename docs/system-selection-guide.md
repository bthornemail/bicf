# System Selection Guide: BICF, CAN-ISA MVP, or Tetragrammatron-OS?

**Version:** 1.0.0
**Last Updated:** 2025-12-20

This guide helps you choose the right system for your use case among the three computation systems in this repository.

---

## Table of Contents

1. [Quick Decision](#quick-decision)
2. [Comprehensive Decision Matrix](#comprehensive-decision-matrix)
3. [Use Case Examples](#use-case-examples)
4. [Migration Paths](#migration-paths)
5. [Maturity Assessment](#maturity-assessment)
6. [Getting Started with Your Choice](#getting-started-with-your-choice)

---

## Quick Decision

### Answer These Questions:

**1. What is your primary goal?**
- **Production deployment** → Use **BICF Production System**
- **Minimal embedded VM** → Use **CAN-ISA MVP**
- **Formal research** → Use **Tetragrammatron-OS**

**2. What is your risk tolerance?**
- **Low risk (need stability)** → Use **BICF Production System**
- **Medium risk (field testing OK)** → Use **CAN-ISA MVP**
- **High risk (research/experimental)** → Use **Tetragrammatron-OS**

**3. What documentation level do you need?**
- **Comprehensive production docs** → Use **BICF Production System**
- **Minimal quick-start** → Use **CAN-ISA MVP**
- **RFC-driven specifications** → Use **Tetragrammatron-OS**

**4. What hardware are you targeting?**
- **ESP32 + Pico with MQTT** → **BICF** or **CAN-ISA MVP**
- **ESP32 only (minimal)** → **CAN-ISA MVP**
- **ESP32 + Android Termux** → **Tetragrammatron-OS**

**5. Do you need formal proofs?**
- **Yes, complete and verified** → **BICF Production System** (Lean/Coq 100% complete)
- **Yes, but in development** → **Tetragrammatron-OS** (20 invariants specified)
- **Not critical** → **CAN-ISA MVP** (minimal proofs)

---

## Comprehensive Decision Matrix

| Criterion | BICF Production System | CAN-ISA MVP | Tetragrammatron-OS |
|-----------|----------------------|-------------|---------------------|
| **Maturity** | ✅ Production-ready | ⚠️ Proof-of-concept | ⚠️ Research-grade |
| **Primary Use Case** | Distributed computation, CanvasL execution | Minimal embedded polynomial VM | Formal research, proof-carrying code |
| **Artifact Format** | `.clbc` | `.canbc` | `.canb` |
| **VM Core** | Record-stream processor | Polynomial engine (F₂[x]) | Fold engine (8-tuple registers) |
| **Bytecode Encoding** | Variable-length records | Variable (1-3 bytes) | Fixed 32-bit instructions |
| **State Model** | Environment (alist) | Single polynomial | 8 semantic registers + object pool |
| **Execution Model** | CanvasL interpreter | Polynomial operations | Fold semantics (idempotent) |
| **Opcode Count** | ~20 (CanvasL operations) | 16 (minimal) | ~25 (fold + geometry) |
| **Hardware Support** | ✅ ESP32 (S3/C6)<br/>✅ Pico 2W | ✅ ESP32 (S3/C6)<br/>⚠️ Pico 2W (planned) | ⚠️ ESP32 (UART bridge)<br/>⚠️ Pico 2W (planned)<br/>✅ Android Termux |
| **Network** | MQTT (WiFi) | MQTT (WiFi) | UART bridge (WiFi planned) |
| **Formal Verification** | ✅ Lean 4 (100% complete)<br/>✅ Coq (100% complete) | ⚠️ Minimal (relies on BICF proofs) | ⚠️ Lean (20 invariants specified) |
| **Proofs Status** | ✅ Complete, no `sorry`/`Admitted` | N/A | ⚠️ Pending implementation |
| **Documentation** | ✅ 8 production docs<br/>✅ Comprehensive RFCs | ⚠️ 1 minimal doc | ✅ 6 RFCs<br/>✅ 40+ dev docs |
| **RFC Governance** | 7 BICF RFCs | Implicit | 6 explicit RFCs |
| **Tools** | ✅ CLI, Docker, LSP<br/>✅ Scheme API | ✅ Assembler, runner<br/>✅ 3-device demos | ✅ Assembler<br/>✅ Geometry renderer |
| **Tests** | ✅ Unit, integration, E2E<br/>✅ Property-based | ✅ Minimal golden tests | ⚠️ In development |
| **CI/CD** | ✅ Docker Compose<br/>✅ GitHub Actions ready | ⚠️ Manual scripts | ⚠️ Manual scripts |
| **Flash Size (ESP32)** | ~800KB | ~600KB (smallest) | ~700KB (estimated) |
| **RAM Usage (ESP32)** | ~150KB | ~80KB (smallest) | ~120KB (estimated) |
| **Typical Program Size** | 10KB-100KB (JSONL) | 100-1000 bytes | 1KB-10KB |
| **Deployment Status** | ✅ Deployed in production | ⚠️ Field testing | ⚠️ Active development |
| **Breaking Changes Risk** | Low (stable API) | Medium (evolving) | High (research) |
| **Learning Curve** | Medium (comprehensive docs) | Low (minimal API) | High (RFC-driven) |
| **Community Support** | Production team + docs | Minimal | Research contributors |
| **Recommended For** | Production systems | Embedded prototypes | Research projects |

### Legend:
- ✅ Available and stable
- ⚠️ Partial / in development / experimental
- ❌ Not available

---

## Use Case Examples

### BICF Production System

#### Use Case 1: Production CanvasL Execution
**Scenario**: You have CanvasL JSONL programs that need deterministic, distributed execution with formal guarantees.

**Why BICF**:
- ✅ Full CanvasL JSONL schema validation
- ✅ FANO/PCG boundary validation
- ✅ Phase-ordered execution (Boundary → Ticket → Guarantee)
- ✅ Production-ready error handling
- ✅ Comprehensive logging and monitoring
- ✅ Docker orchestration

**Example**:
```bash
# Compile CanvasL to .clbc
guile -s src/clbc/compiler.scm program.jsonl program.clbc

# Run with Docker
docker run bicf/production:latest interpreter program.clbc

# Deploy with Docker Compose
docker-compose up
```

---

#### Use Case 2: Native Repository Runtime (NRR) Storage
**Scenario**: You need content-addressed storage with deterministic replay, independent of Git.

**Why BICF**:
- ✅ Content-addressed storage (hash-based)
- ✅ Append-only log for deterministic replay
- ✅ Multiple storage backends (file, in-memory, embedded)
- ✅ Git adapter for optional backward compatibility
- ✅ Polynomial state compression for constant memory replay

**Example**:
```scheme
; Initialize NRR
(load "src/nrr/storage.scm")
(init-nrr 'file "/path/to/repo")

; Store content
(define ref (nrr-put "content"))

; Log execution
(nrr-append (make-log-entry 0 'boundary ref))

; Replay from log
(define entries (nrr-log))
(replay-from-log entries)
```

---

#### Use Case 3: Distributed Deterministic Consensus
**Scenario**: Multiple nodes need to reach consensus on computation results without voting.

**Why BICF**:
- ✅ PCG (Pair-Cover Guarantee) deterministic validation
- ✅ FANO boundary overlap guarantees
- ✅ No probabilistic elements
- ✅ Machine-checkable constraints
- ✅ Formal proofs (Lean, Coq)

**Example**:
```bash
# Each node executes the same CanvasL program
node1$ guile -s src/canvasl/interpreter.scm program.jsonl
node2$ guile -s src/canvasl/interpreter.scm program.jsonl
node3$ guile -s src/canvasl/interpreter.scm program.jsonl

# All nodes produce identical transcript hashes
# Consensus achieved without communication
```

---

#### Use Case 4: API Integration and Service Orchestration
**Scenario**: You need to integrate boundary-interior computation with existing services.

**Why BICF**:
- ✅ Scheme API for programmatic access
- ✅ Docker interface for service isolation
- ✅ JSONL input/output for interoperability
- ✅ Comprehensive error handling
- ✅ Production-ready logging

**Example**:
```bash
# Docker API
docker run bicf/production:latest help
docker run bicf/production:latest interpreter trace.jsonl

# Scheme API
guile -c '(load "src/integration/bicf-system.scm")
          (init-bicf-system)
          (execute-canvasl "program.jsonl")'
```

---

### CAN-ISA MVP

#### Use Case 1: Minimal Embedded Polynomial Computation
**Scenario**: You need the smallest possible VM for polynomial operations on ESP32.

**Why CAN-ISA MVP**:
- ✅ Smallest flash footprint (~600KB)
- ✅ Minimal RAM usage (~80KB)
- ✅ 16 minimal opcodes (easy to understand)
- ✅ Direct polynomial operations (F₂[x])
- ✅ Quick deployment

**Example**:
```bash
# Assemble polynomial program
guile -s tools/can-asm.scm tests/canisa/canisa-mini.input.scm /tmp/demo.canbc

# Run and get hash
guile -s tools/can-run.scm /tmp/demo.canbc
# Output: hash=0xabcd1234...

# Flash to ESP32
scripts/flash-esp32-mqtt-clbc.sh /dev/ttyUSB0

# Send via MQTT
mosquitto_pub -t "canbc/device-1/cmd" -m "EXEC $(base64 /tmp/demo.canbc)"
```

---

#### Use Case 2: 3-Device Heterogeneous Network Validation
**Scenario**: You want to prove deterministic execution across different ESP32 architectures.

**Why CAN-ISA MVP**:
- ✅ MQTT-based coordination
- ✅ Automatic device discovery (zero-config)
- ✅ UDP discovery support
- ✅ Canonical state hashing (SHA-256)
- ✅ Simple demo scripts

**Example**:
```bash
# Run 3-device demo with auto-discovery
scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --auto

# Output:
# Device canbc-auto-1 (ESP32-S3): hash=0xabcd1234...
# Device canbc-auto-2 (ESP32-C6): hash=0xabcd1234...
# Device canbc-auto-3 (ESP32-S3): hash=0xabcd1234...
# ✅ All hashes match - determinism proven

# Benchmark 25 runs
scripts/bench-canbc-3esp.sh --broker 127.0.0.1 --runs 25
# Output: Average exec_ms: 42ms
```

---

#### Use Case 3: Field Testing CAN-ISA Semantics
**Scenario**: You're validating polynomial canonical semantics before committing to formal specification.

**Why CAN-ISA MVP**:
- ✅ Proof-of-concept implementation
- ✅ Quick iteration with Scheme assembler
- ✅ Minimal dependencies
- ✅ Easy to modify and experiment

**Example**:
```scheme
; Write test program (Scheme S-expression)
(begin
  (term-new 1)
  (state-add 1)
  (state-norm)
  (state-hash)
  (halt))

; Assemble and run
$ guile -s tools/can-asm.scm test.scm test.canbc
$ guile -s tools/can-run.scm test.canbc
hash=0x...

; Test on hardware
$ mosquitto_pub -t "canbc/esp32-1/cmd" -m "EXEC $(base64 test.canbc)"
```

---

#### Use Case 4: Quick ESP32 Prototyping
**Scenario**: You need to deploy polynomial computation to ESP32 quickly without extensive setup.

**Why CAN-ISA MVP**:
- ✅ Single flash script
- ✅ Zero-config MQTT (auto-generated device IDs)
- ✅ Minimal codebase to understand
- ✅ Fast compile and flash (~2 minutes)

**Example**:
```bash
# Flash ESP32 (one command)
scripts/flash-esp32-mqtt-clbc.sh /dev/ttyUSB0

# Device auto-registers as canbc-<MAC>
# No configuration needed

# Send program via MQTT immediately
mosquitto_pub -t "canbc/canbc-aabbccdd/cmd" -m "EXEC $(base64 program.canbc)"

# Get result
mosquitto_sub -t "canbc/canbc-aabbccdd/result"
# {"hash": "0x...", "status": "ok", "exec_ms": 42}
```

---

### Tetragrammatron-OS

#### Use Case 1: Formal Research on Proof-Carrying Bytecode
**Scenario**: You're researching how to embed formal proofs directly in bytecode.

**Why Tetragrammatron-OS**:
- ✅ 6 normative RFCs defining complete semantics
- ✅ 20 Lean invariants specified
- ✅ Proof-carrying bytecode design
- ✅ Formal verification framework
- ✅ RFC-driven development

**Example**:
```bash
cd apps/tetragrammatron-os

# Study RFCs
cat rfc/RFC-0000-can-isa-invariants.md
cat rfc/RFC-0009-origami-fold-vm.md
cat rfc/RFC-0012-binary-encoding.md

# Review Lean proofs
cat proof/RFC0012_FoldVM.lean

# Implement VM extensions based on RFCs
vim vm/can_vm.c
```

---

#### Use Case 2: Geometric Computation with Fano Projections
**Scenario**: You're exploring how Fano plane geometry relates to computation.

**Why Tetragrammatron-OS**:
- ✅ Explicit PROJ_FANO operator
- ✅ Geometry rendering (SVG, GLB)
- ✅ Fano merge gate in repository lattice
- ✅ 7-point/7-line incidence structure
- ✅ LIFT_3D mesh semantics (RFC-0017)

**Example**:
```bash
cd apps/tetragrammatron-os

# Generate Fano SVG
python core/geometry/fano_svg.py --output fano.svg

# Generate triad SVG
python core/geometry/triad_to_svg.py --triad 0 --output triad_0.svg

# Explore repository lattice
tree repo.canvasl/
# 8³ = 512-node semantic topology
```

---

#### Use Case 3: RFC Compliance Validation
**Scenario**: You're building a system that must comply with formal specifications.

**Why Tetragrammatron-OS**:
- ✅ Normative RFCs as ground truth
- ✅ Explicit invariant checking (ASSERT_CANON, ASSERT_IDEMP, ASSERT_FANO)
- ✅ VM implementation follows RFC-0012 exactly
- ✅ Assembler validates RFC-0009 semantics
- ✅ Test vectors for golden compliance

**Example**:
```bash
cd apps/tetragrammatron-os

# Validate bytecode against RFC-0012
python tests/test_codec.py

# Check invariants against RFC-0000
python core/geometry/invariants.py

# Generate compliance report
scripts/gen-compliance-report.sh > compliance.md
```

---

#### Use Case 4: Cross-Platform Deterministic Execution Research
**Scenario**: You're researching how to achieve bit-identical results across wildly different platforms (ESP32, Android, x86-64).

**Why Tetragrammatron-OS**:
- ✅ Fixed 32-bit instructions (predictable)
- ✅ Fold semantics (idempotent, order-independent)
- ✅ Canonical enforcement (ASSERT_CANON)
- ✅ Platform time sources (RFC-0013)
- ✅ Barrier semantics (BARRIER_T)

**Example**:
```bash
# Compile same program for all platforms
cd apps/tetragrammatron-os

# x86-64
make clean && make
./build/can_vm examples/fold_min.canb

# ESP32 (cross-compile)
make esp32
scripts/flash-esp32-can.sh /dev/ttyUSB0
scripts/run-canb.sh /dev/ttyUSB0 examples/fold_min.canb

# Android Termux
make android
./build/can_vm_android examples/fold_min.canb

# Compare hashes - should be identical
```

---

## Migration Paths

### Scenario: Starting Fresh

**Recommendation**: Choose based on your goal (see Quick Decision above)

**No Migration Needed**: Start with the right system from day one

---

### Scenario: From CLBC to CAN-ISA MVP

**Difficulty**: ⚠️ High (different execution models)

**Recommended Approach**: **Parallel Deployment**

**Why Not Migrate**:
- Different use cases (production vs field testing)
- Different state models (environment vs polynomial)
- Different semantics (CanvasL vs polynomial operations)

**If You Must Migrate**:
1. **Analyze CLBC program**: Identify polynomial operations
2. **Manual Translation**: Rewrite as polynomial bytecode
3. **Validation**: Compare outputs (may not be 1:1)
4. **Testing**: Extensive cross-platform testing

**Better Alternative**:
- Use **CLBC** for production CanvasL execution
- Use **CAN-ISA MVP** for minimal embedded polynomial experiments
- Run both systems in parallel for different workloads

---

### Scenario: From CAN-ISA MVP to Tetragrammatron-OS

**Difficulty**: ⚠️ Medium (conceptual extension)

**Recommended Approach**: **Extend MVP Programs**

**Migration Strategy**:
1. **Map MVP state → Tetragrammatron-OS `state` register**
2. **Translate opcodes**:
   - `STATE_ADD` → operations on `state` register
   - `STATE_GCD` → `MEET_GCD state r1 r2`
   - `STATE_LCM` → `JOIN_LCM state r1 r2`
   - `STATE_NORM` → `CANON state`
   - `STATE_HASH` → `COMMIT_HASH state`
3. **Use object pool** for polynomial handles
4. **Add assertions** (ASSERT_CANON, ASSERT_IDEMP)

**Example Translation**:

**CAN-ISA MVP Program**:
```
TERM_NEW 1          ; Create polynomial handle 1
STATE_ADD 1         ; Add handle 1 to state
STATE_NORM          ; Normalize
STATE_HASH          ; Hash
HALT
```

**Tetragrammatron-OS Equivalent**:
```
ALLOC state 64      ; Allocate state object
ALLOC r1 64         ; Allocate handle 1
COPY r1 state       ; state += r1 (via fold semantics)
CANON state         ; Normalize
COMMIT_HASH state   ; Hash → result register
HALT
```

**When to Migrate**:
- You want to explore formal RFC-driven extensions
- You need proof-carrying bytecode
- You're doing research on geometric computation

**When Not to Migrate**:
- Production deployment (use BICF instead)
- Minimal embedded (CAN-ISA MVP is already minimal)

---

### Scenario: From BICF to Tetragrammatron-OS

**Difficulty**: ⚠️ High (parallel tracks)

**Recommended Approach**: **Parallel Development with Shared Foundations**

**Why Not Migrate**: Different purposes (production vs research)

**Shared Components You Can Reuse**:
- Polynomial algebra (`src/aal/polynomials.scm`)
- Fano plane geometry
- Deterministic execution principles
- Hardware infrastructure (ESP32, Pico)
- Formal verification patterns (Lean, Coq)

**Better Alternative**: Parallel tracks
- **BICF**: Continue production CanvasL features
- **Tetragrammatron-OS**: Explore proof-carrying computation
- **Share**: Polynomial proofs, geometric foundations, hardware code

**Example Shared Code**:
```bash
# BICF uses polynomial algebra
src/aal/polynomials.scm

# Tetragrammatron-OS can import same operations
apps/tetragrammatron-os/vm/can_poly.c
# (C port of polynomials.scm)

# Both use Fano plane
src/fano/fano-checker.scm  # BICF
apps/tetragrammatron-os/core/geometry/fano_svg.py  # Tetragrammatron-OS
```

---

## Maturity Assessment

### BICF Production System

**Maturity**: ✅ Production-Ready

**Indicators**:
- ✅ Deployed in production environments
- ✅ 8 comprehensive production documents
- ✅ Formal verification 100% complete (Lean/Coq)
- ✅ Docker orchestration and CI/CD ready
- ✅ Comprehensive testing (unit, integration, E2E)
- ✅ Stable APIs with semantic versioning
- ✅ Production error handling and logging
- ✅ Active maintenance and support

**Risk Level**: 🟢 Low

**Breaking Changes**: Rare, documented in release notes

**Support**: Full production team + comprehensive docs

---

### CAN-ISA MVP

**Maturity**: ⚠️ Proof-of-Concept / Field Testing

**Indicators**:
- ⚠️ Field testing on ESP32 hardware
- ⚠️ 1 minimal documentation file
- ⚠️ Minimal formal verification (relies on BICF)
- ⚠️ Manual deployment scripts
- ⚠️ Basic golden tests only
- ⚠️ Evolving APIs
- ⚠️ Experimental features (UDP discovery)
- ✅ Stable core polynomial operations

**Risk Level**: 🟡 Medium

**Breaking Changes**: Possible as semantics evolve

**Support**: Minimal docs, community contributors

---

### Tetragrammatron-OS

**Maturity**: ⚠️ Research-Grade / Active Development

**Indicators**:
- ⚠️ Active development, not production-ready
- ✅ 6 normative RFCs (complete specifications)
- ⚠️ Lean proofs specified but pending implementation
- ⚠️ Manual build and test processes
- ⚠️ Many VM operations stubbed
- ⚠️ APIs subject to change based on RFC evolution
- ✅ Well-documented (40+ dev docs)
- ⚠️ Research contributors, experimental

**Risk Level**: 🔴 High

**Breaking Changes**: Frequent as research progresses

**Support**: RFC documentation, research community

---

## Getting Started with Your Choice

### Getting Started with BICF Production System

**Quick Start**:
```bash
# Clone repo
git clone https://github.com/your-org/bicf-production
cd bicf-production

# Read documentation
cat production-docs/usage-guide.md
cat production-docs/architecture.md

# Build and test
./scripts/build.sh
./scripts/test.sh

# Run CanvasL interpreter
guile -s src/canvasl/interpreter.scm examples/program.jsonl

# Docker deployment
docker build -t bicf/production:latest .
docker run bicf/production:latest help
```

**Next Steps**:
1. Read [Usage Guide](../production-docs/usage-guide.md)
2. Explore [API Reference](../production-docs/api-reference.md)
3. Try [Examples](../README.md#usage-examples)
4. Set up [Docker Deployment](../deployment/README.md)

---

### Getting Started with CAN-ISA MVP

**Quick Start**:
```bash
# Read documentation
cat docs/canisa-mvp.md

# Assemble example program
guile -s tools/can-asm.scm tests/canisa/canisa-mini.input.scm /tmp/demo.canbc

# Run locally
guile -s tools/can-run.scm /tmp/demo.canbc

# Flash ESP32
scripts/flash-esp32-mqtt-clbc.sh /dev/ttyUSB0

# Run 3-device demo
scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --auto
```

**Next Steps**:
1. Read [CAN-ISA MVP Documentation](canisa-mvp.md)
2. Study polynomial operations in `src/aal/polynomials.scm`
3. Write your own `.canbc` programs
4. Test on ESP32 hardware

---

### Getting Started with Tetragrammatron-OS

**Quick Start**:
```bash
# Navigate to project
cd apps/tetragrammatron-os

# Read documentation
cat README.md
cat IMPLEMENTATION.md

# Study RFCs
ls rfc/
cat rfc/RFC-0000-can-isa-invariants.md

# Build VM
cd vm
make

# Run example (when implementation complete)
../build/can_vm examples/fold_min.canb
```

**Next Steps**:
1. Read [Tetragrammatron-OS README](../apps/tetragrammatron-os/README.md)
2. Study [6 RFCs](../apps/tetragrammatron-os/rfc/)
3. Review [Lean proofs](../apps/tetragrammatron-os/proof/RFC0012_FoldVM.lean)
4. Explore [Repository lattice](../apps/tetragrammatron-os/repo.canvasl/)
5. Contribute to [Implementation](../apps/tetragrammatron-os/IMPLEMENTATION.md)

---

## Still Not Sure?

### Contact and Resources

**Read More**:
- [Tetragrammatron-OS and BICF Relationship](tetragrammatron-bicf-relationship.md) - High-level overview
- [CAN-ISA Evolution](can-isa-evolution.md) - Technical deep-dive

**Ask Questions**:
- Open an issue on GitHub
- Consult the production team
- Join the research community

**Experiment**:
- Try all three systems with small test programs
- Compare results
- Evaluate based on your specific needs

---

**Last Updated**: 2025-12-20
**Maintained By**: BICF Production Team
