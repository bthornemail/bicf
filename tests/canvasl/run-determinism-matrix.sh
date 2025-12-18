#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

trace_id() {
  local jsonl="$1"
  GUILE_AUTO_COMPILE=0 guile -c '
    (load (cadr (command-line)))
    (init-nrr (quote memory))
    (let* ((path (caddr (command-line)))
           (st (execute-canvasl1-jsonl path))
           (p (assoc (quote trace_id) st)))
      (display (if p (cdr p) ""))
      (newline))' \
    "$ROOT/src/canvasl/canvasl1-jsonl.scm" \
    "$jsonl"
}

BASE="$ROOT/tests/canvasl/matrix.base.jsonl"
PERM="$ROOT/tests/canvasl/matrix.permuted.jsonl"

# 1) Permutation invariance + duplicate handling: both should normalize to the same trace_id
tid1="$(trace_id "$BASE")"
tid2="$(trace_id "$PERM")"

if [ -z "$tid1" ] || [ -z "$tid2" ]; then
  echo "trace_id missing" >&2
  exit 1
fi

if [ "$tid1" != "$tid2" ]; then
  echo "trace_id mismatch" >&2
  echo "base: $tid1" >&2
  echo "perm: $tid2" >&2
  exit 1
fi

# 2) Corruption check (CLBC-level): flip a byte and ensure VM reports failure.
GUILE_AUTO_COMPILE=0 guile -c '
  (load (cadr (command-line)))
  (load (caddr (command-line)))
  (load (cadddr (command-line)))
  (define (get-records path)
    (call-with-input-file path
      (lambda (p)
        (let loop ((out (quote ())))
          (let ((line (read-line p)))
            (if (eof-object? line)
                (reverse out)
                (let ((t (string-trim-both line)))
                  (if (or (string=? t "") (char=? (string-ref t 0) #\#))
                      (loop out)
                      (loop (cons (normalize-record (parse-json-line t)) out))))))))))
  (define records (get-records (list-ref (command-line) 4)))
  (define enc (canvasl-records->clbc (map canvasl1-record->clbc-record records)))
  (define bs (cdr enc))
  (define res (vm-run-clbc-bytes bs))
  (if (not (assoc (quote ok?) res)) (error "vm result missing ok?") #t)
  (define ok0 (cdr (assoc (quote ok?) res)))
  (if (not ok0) (error "expected base CLBC to be ok") #t)
  (define corrupted (append (list (logxor (car bs) 1)) (cdr bs)))
  (define res2
    (catch #t
      (lambda () (vm-run-clbc-bytes corrupted))
      (lambda (k . args) #f)))
  (if res2
      (let ((ok1 (cdr (assoc (quote ok?) res2))))
        (if ok1 (error "expected corrupted CLBC to fail") #t))
      #t)
  (display "ok")
  (newline)
  ' \
  "$ROOT/src/clbc/compiler.scm" \
  "$ROOT/src/vm/clbc-vm.scm" \
  "$ROOT/src/canvasl/canvasl1-jsonl.scm" \
  "$BASE"

echo "ok"


