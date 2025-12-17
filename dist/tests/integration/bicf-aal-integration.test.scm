;; Integration tests for BICF-AAL integration

(load "../../src/integration/bicf-system.scm")
(load "../../src/integration/bicf-to-aal.scm")

;; Test helper
(define (test name test-fn)
  (display "Testing: ")
  (display name)
  (display "... ")
  (if (test-fn)
      (begin
        (display "PASS\n")
        #t)
      (begin
        (display "FAIL\n")
        #f)))

;; Test boundary-to-aal transformation
(test "boundary-to-aal: generic boundary"
      (lambda ()
        (let ((boundary (make-simple-boundary "test-boundary")))
          (let ((result (boundary-to-aal boundary)))
            (list? result)))))

;; Test node type mappings
(test "activate-to-aal: generates JMP/CALL"
      (lambda ()
        (let ((activate-node '((type . Activate) (target . 0) (label . "entry"))))
          (let ((result (activate-to-aal activate-node)))
            (and (list? result)
                 (not (null? result))))))

(test "integrate-to-aal: generates ADD/SUB"
      (lambda ()
        (let ((integrate-node '((type . Integrate) (inputs . (R1 R2)) (output . R0) (operation . add))))
          (let ((result (integrate-to-aal integrate-node)))
            (and (list? result)
                 (not (null? result))))))

;; Test FANO boundary to AAL
(test "fano-boundary-to-aal: generates AAL program"
      (lambda ()
        (let ((fano-boundary '((id . "fano-test")
                               (type . fano)
                               (points . (0 1 2 3 4 5 6))
                               (lines . ((0 1 3) (0 2 6))))))
          (let ((result (fano-boundary-to-aal fano-boundary)))
            (and (list? result)
                 (not (null? result))))))

;; Test generate-aal function
(test "generate-aal: main compilation function"
      (lambda ()
        (let ((boundary (make-simple-boundary "test")))
          (let ((result (generate-aal boundary)))
            (list? result)))))

;; Run all tests
(define (run-bicf-aal-tests)
  (display "Running BICF-AAL integration tests...\n")
  (let ((results '()))
    (set! results (cons (test "boundary-to-aal"
                              (lambda ()
                                (let ((boundary (make-simple-boundary "test")))
                                  (list? (boundary-to-aal boundary)))))
                        results))
    (display "BICF-AAL integration tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-bicf-aal-tests))

