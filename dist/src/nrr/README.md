# Native Repository Runtime (NRR)

## Overview

Native Repository Runtime (NRR) provides a minimal, Git-independent repository abstraction for BICF/CanvasL. It implements content-addressed storage and append-only logs, enabling deterministic replay and embedded system deployment.

## Core Interface

```scheme
;; Minimal NRR interface
(define (nrr-put content) -> ref)      ; Store content, return reference
(define (nrr-get ref) -> content)      ; Retrieve content by reference
(define (nrr-append entry))             ; Append log entry
(define (nrr-log) -> [entries])        ; Retrieve all log entries
```

## Features

- Content addressing (hash-based references)
- Append-only log (deterministic replay)
- Storage backends (file, memory, embedded)
- Git adapter (optional backward compatibility)
- Polynomial state compression
- CanvasL integration

## Usage

```scheme
;; Initialize NRR
(load "src/nrr/storage.scm")
(init-nrr "repo/")

;; Store content
(define ref (nrr-put "content"))
(define content (nrr-get ref))

;; Log execution
(nrr-append (make-log-entry 0 'boundary ref))

;; Replay from log
(define entries (nrr-log))
(replay entries)
```

## Architecture

NRR separates concerns:
- **Content Addressing:** Hash-based references
- **Storage:** Backend-agnostic content storage
- **Logging:** Append-only execution log
- **Replay:** Deterministic state reconstruction

## References

- NRR Proposal: `dev-docs/Native Repository Runtime.md`
- CanvasL Integration: `src/canvasl/nrr-backend.scm`

