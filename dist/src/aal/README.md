# AAL (Assembly–Algebra Language) Module

This module implements the complete AAL v3.2 compiler/interpreter system.

## Overview

AAL is a formally verified language that:
- Executes machine code as polynomial transformations over $\mathbb{F}_2[x]$
- Provides a complete graded modal type system tracking 11 layers of abstraction (D0-D10)
- Establishes a mechanically verified bridge from XOR gates to the Fano Plane
- Includes certified implementation of the Hamming (7,4) code

## Module Structure

- `polynomials.scm` - Polynomial algebra over $\mathbb{F}_2[x]$
- `ast.scm` - Abstract syntax tree definitions
- `parser.scm` - EBNF grammar parser
- `well-formed.scm` - Well-formedness judgments
- `types.scm` - Graded modal type system (D0-D10)
- `semantics.scm` - Small-step semantics
- `geometry.scm` - D9 Fano Plane mapping
- `compiler.scm` - Main compiler entry point
- `interpreter.scm` - Alternative interpreter mode

## Usage

```scheme
;; Load AAL compiler
(load "src/aal/compiler.scm")

;; Compile an AAL program
(define program (parse-aal "MOV R0, #1\nADD R0, R1"))
(define compiled (compile program))

;; Or use interpreter
(load "src/aal/interpreter.scm")
(define result (interpret program))
```

## References

- AAL v3.2 Specification: `dev-docs/Assembly–Algebra Language v3.2/`
- Implementation Plan: `dev-docs/BICF Production System - Full Implementation Plan.md`

