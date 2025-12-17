# AGENTS.md Specification
## CanvasL-POLY + BICF Aligned Agent Boundary Contract

**Version:** 2.0.0  
**Status:** Normative Specification  
**Date:** December 2025  
**Alignment:** RFC-BICF-CANVASL-POLY-001 Compliant  

---

## 1. Normative Purpose

AGENTS.md is a **Boundary Execution Contract** that defines admissible operations within a repository subtree. It transforms directories from passive containers to **explicitly bounded execution contexts** where:

- **Humans** operate with clear constraints
- **AI Systems** execute within verifiable boundaries  
- **Automations** maintain structural invariants
- **Merges** validate boundary compatibility

This document is **executable, auditable, and merge-relevant** under mind-git semantics.

---

## 2. Core Concepts (BICF-Aligned)

| Concept | AGENTS.md Interpretation | CanvasL Mapping |
|---------|-------------------------|-----------------|
| **Boundary** | AGENTS.md file contents | `boundary` node in JSONL |
| **Interior** | Code changes within directory | `interior` with hash |
| **Validity** | All constraints satisfied | Schema validation pass |
| **Projection** | Export to other formats | Multi-format export |
| **Anchor** | Git commit hash | `boundary_anchor` field |

---

## 3. File Structure (Normative Template)

Every AGENTS.md MUST contain these sections in order:

### 3.1 Component Identity
```markdown
## Component Identity

- **Name:** [component-name]
- **Path:** [relative/path/from/root]
- **Component-ID:** [content-hash]
- **Layer:** [1-8 from Universal Layer Model]
- **Boundary Hash:** [sha256-of-this-file]
- **Created:** [ISO-8601-timestamp]
- **Last Validated:** [ISO-8601-timestamp]
```

### 3.2 Boundary Constraints
```markdown
## Boundary Constraints

### MUST (Affirmative Constraints)
- [ ] Preserve public interfaces: [list]
- [ ] Maintain purity property: [true/false]
- [ ] Respect complexity budget: [max-value]
- [ ] Keep dependencies explicit
- [ ] Pass all verification checks

### MUST NOT (Prohibitive Constraints)
- [x] Introduce implicit state
- [x] Violate repository schemas
- [x] Create hidden dependencies
- [x] Bypass declared interfaces
- [x] Exceed IO permissions
```

### 3.3 Layer-Specific Responsibilities
```markdown
## Layer-Specific Responsibilities

### Primary Role
[Description of component's core purpose according to its layer]

### Layer-Required Invariants
- **If Layer 1 (Mathematical):** All theorems must be machine-verifiable
- **If Layer 2 (Core):** All functions must be deterministic
- **If Layer 3 (API):** Interface contracts must be stable
- **If Layer 4 (Services):** Business logic must be testable
- **If Layer 5 (Data):** Schemas must be explicit
- **If Layer 6 (UI):** State transitions must be defined
- **If Layer 7 (Tests):** Coverage must be measurable
- **If Layer 8 (Docs):** Accuracy must be verifiable
```

### 3.4 Admissible Operations
```markdown
## Admissible Operations

### Agents MAY
- [Operation 1] when [condition]
- [Operation 2] if [constraint]
- [Operation 3] provided [validation]

### Execution Examples
```
refactor internal implementation
add tests with coverage > threshold
update documentation to match code
optimize within complexity budget
```

### Forbidden Operations
```
modify exported interfaces without versioning
introduce network calls without declaration
violate purity guarantees
exceed declared complexity limits
```

### 3.5 Formal Properties
```markdown
## Formal Properties

### Formal System
- [ ] Lean 4
- [ ] Coq
- [ ] AAL
- [ ] Prolog
- [ ] Datalog
- [ ] None

### Proven Invariants
1. **Theorem:** [theorem-name]
   - **Statement:** [formal-statement]
   - **Proof:** [proof-reference]
   - **Status:** [verified/assumed]

2. **Property:** [property-name]
   - **Type:** [safety/liveness/invariant]
   - **Verification:** [method]
   - **Scope:** [component/repository]
```

### 3.6 Interface Specifications
```markdown
## Interface Specifications

### Provided Interfaces
| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| [interface] | [function/type/endpoint] | [stable/experimental] | [purpose] |

### Required Dependencies
| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| [dependency] | [semver-range] | [reason] | [yes/no] |

### Data Contracts
```json
{
  "input_schema": {},
  "output_schema": {},
  "error_cases": []
}
```

### 3.7 Complexity Governance
```markdown
## Complexity Governance

### Current Metrics
- **Cyclomatic Complexity:** [value]
- **Cognitive Complexity:** [value] 
- **Halstead Volume:** [value]
- **Dependency Count:** [value]

### Budget Allocation
- **Maximum Allowed:** [budget-value]
- **Current Usage:** [current-value]
- **Remaining Budget:** [remaining]
- **Escalation Threshold:** [90%]

### Budget Enforcement
- ❌ Block commits exceeding budget
- ⚠️ Warn at 80% utilization  
- ✅ Allow optimizations reducing complexity
```

### 3.8 Verification & Testing
```markdown
## Verification & Testing

### Required Tests
- [ ] Unit Tests: [min-count]
- [ ] Integration Tests: [min-count]
- [ ] Property Tests: [min-count]
- [ ] Formal Verification: [if-applicable]

### Test Locations
```
./tests/unit/
./tests/integration/
./tests/property/
```

### Coverage Requirements
- **Line Coverage:** ≥ [percentage]%
- **Branch Coverage:** ≥ [percentage]%
- **Mutation Score:** ≥ [percentage]%

### Continuous Validation
- [ ] Pre-commit hooks validate AGENTS.md
- [ ] CI runs all declared verifications
- [ ] Nightly runs check boundary integrity
```

### 3.9 CanvasL Integration
```markdown
## CanvasL Integration

### Boundary Definition
```json
{
  "type": "boundary",
  "id": "[boundary-hash]",
  "scope": "[directory-path]",
  "layer": [layer-number],
  "constraints": "[constraints-hash]",
  "created": "[timestamp]"
}
```

### Execution Semantics
- **Phase:** [execution-phase-number]
- **Dependencies:** [list-of-boundary-ids]
- **Preconditions:** [must-be-true-before]
- **Postconditions:** [must-be-true-after]

### Projection Mappings
| CanvasL Field | AGENTS.md Section | Export Format |
|---------------|-------------------|---------------|
| `boundary.id` | Component Identity | JSON, JSON-LD |
| `constraints` | Boundary Constraints | RDF/Turtle |
| `interfaces` | Interface Specifications | OpenAPI |
| `verification` | Verification & Testing | JUnit XML |
```

### 3.10 Merge Semantics
```markdown
## Merge Semantics

### Merge Compatibility
This component MAY be merged IF:

#### Required Conditions
- [ ] Boundary hash matches expected value
- [ ] All tests pass
- [ ] No AGENTS.md constraint is violated
- [ ] Complexity budget is respected
- [ ] Dependencies remain compatible

#### Conflict Resolution
**If boundary has diverged:**
1. Regenerate AGENTS.md from current state
2. Validate against repository constraints
3. Update boundary hash
4. Re-run all verifications

**If constraints conflict:**
1. Escalate to repository maintainer
2. Adjust boundary definition if needed
3. Update dependent components
4. Log resolution in mind-git

### Merge Safety Guarantees
- ✅ Deterministic merge validation
- ✅ No hidden state introduction
- ✅ Backward compatibility check
- ✅ Forward compatibility assessment
```

### 3.11 Change Protocol
```markdown
## Change Protocol

### Modifying This File
1. **Proposal:** Document proposed change in PR
2. **Validation:** Run `mind-git kernel:validate ./`
3. **Impact:** Assess affected components
4. **Approval:** Get review from [roles]
5. **Update:** Modify file and regenerate hash
6. **Verification:** Confirm all tests pass

### Versioning Rules
- **MAJOR:** Breaking boundary changes
- **MINOR:** New admissible operations
- **PATCH:** Clarifications or fixes

### Audit Trail
All changes MUST be:
- Committed with AGENTS.md boundary hash
- Linked to CanvasL execution phase
- Documented in mind-git log
- Validated pre-merge
```

---

## 4. Universal Layer Model Integration

AGENTS.md MUST reference one of 8 Universal Layers:

| Layer | AGENTS.md Implications | Example Components |
|-------|------------------------|-------------------|
| **1. Mathematical** | Must include formal proofs | Theorem provers, Cryptography |
| **2. Core** | Must be deterministic | Algorithms, Data structures |
| **3. API** | Must maintain stability | Interfaces, Protocols |
| **4. Services** | Must be testable | Business logic, Workflows |
| **5. Data** | Must have explicit schemas | Databases, Serialization |
| **6. UI** | Must define state machines | Components, Views |
| **7. Tests** | Must be measurable | Test suites, Benchmarks |
| **8. Documentation** | Must be verifiable | Specifications, Guides |

---

## 5. Tooling Requirements

### 5.1 Validation Commands
```bash
# Validate AGENTS.md against repository
mind-git kernel:validate ./component

# Generate AGENTS.md from current state  
mind-git kernel:generate ./component

# Check merge compatibility
mind-git kernel:check-merge ./component origin/main

# Export boundary to CanvasL
mind-git kernel:export-boundary ./component
```

### 5.2 Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: validate-agents
        name: Validate AGENTS.md
        entry: mind-git kernel:validate
        language: system
        files: ^AGENTS\.md$
        
      - id: check-complexity
        name: Check Complexity Budget
        entry: mind-git kernel:check-complexity
        language: system
        files: \.(py|js|rs|lean)$
```

---

## 6. Compliance Checklist

Before committing, verify:

### Structural Compliance
- [ ] All required sections present
- [ ] Hashes are current and valid
- [ ] Layer assignment is correct
- [ ] No contradictions in constraints

### Semantic Compliance  
- [ ] Admissible operations are explicit
- [ ] Forbidden operations are complete
- [ ] Interfaces are fully specified
- [ ] Dependencies are declared

### Execution Compliance
- [ ] Tests exist and pass
- [ ] Complexity within budget
- [ ] Formal properties verified (if any)
- [ ] Merge conditions satisfied

---

## 7. Examples

### Example 1: Layer 2 Core Component
```markdown
## Component Identity
- **Name:** sorting-algorithms
- **Path:** src/core/sorting
- **Layer:** 2
- **Boundary Hash:** sha256:abc123...

## Boundary Constraints
### MUST
- [ ] Preserve O(n log n) worst-case guarantee
- [ ] Maintain deterministic output
- [ ] Keep memory usage O(1) for in-place sorts

### MUST NOT  
- [x] Introduce non-determinism
- [x] Exceed O(n) memory without explicit option
```

### Example 2: Layer 1 Mathematical Component  
```markdown
## Formal Properties
### Formal System: Lean 4

### Proven Invariants
1. **Theorem:** sorting_correct
   - **Statement:** ∀ (xs : List Nat), is_sorted (sort xs)
   - **Proof:** Sorting.lean:42
   - **Status:** verified
```

---

## 8. Normative References

1. **RFC-BICF-CANVASL-POLY-001** - Base standard
2. **CanvasL JSONL Specification** - Execution format  
3. **Universal Layer Model** - Component classification
4. **mind-git Protocol** - Versioning semantics

---

## 9. Status & Evolution

This specification is:
- ✅ Production ready
- ✅ Standards compliant  
- ✅ Formally grounded
- ✅ Practically validated

**Next steps for implementers:**
1. Add AGENTS.md to key components
2. Integrate validation into CI/CD
3. Train team on boundary semantics
4. Establish escalation protocols

---

*AGENTS.md transforms documentation into execution contracts. It's not what you can read—it's what you can safely do.*