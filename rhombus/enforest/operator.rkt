#lang racket/base
(require racket/base
         syntax/stx
         "private/transform.rkt")

;; See "main.rkt" for general information about operators and parsing.
;;
;; An operator's predence is represented as a list of
;;
;;   (cons/c (or/c identifier? 'default)
;;           (or/c 'stronger 'same 'weaker))
;;
;; where the `car`s of the pairs should be distinct, and 'default
;; stands for every identifier not mentioned. The value 'stronger
;; means that the operator that has this list has a stronger
;; precedence than the one referenced by the identifier. An operator
;; is implicitly the 'same as itself (i.e., not covered by 'default).

(provide operator?
         operator-name
         operator-precedences
         operator-protocol
         operator-proc ; convention depends on category

         prefix-operator
         prefix-operator?

         infix-operator
         infix-operator?
         infix-operator-assoc)

(module+ for-parse
  (provide relative-precedence

           lookup-infix-implicit
           lookup-prefix-implicit

           apply-prefix-direct-operator
           apply-infix-direct-operator
           apply-prefix-transformer-operator
           apply-infix-transformer-operator))

(struct operator (name precedences protocol proc)
  #:guard (lambda (name precedences protocol proc who)
            (unless (identifier? name)
              (raise-argument-error who "identifier?" name))
            (unless (and (list? precedences)
                         (for/and ([p (in-list precedences)])
                           (and (pair? p)
                                (or (eq? (car p) 'default)
                                    (identifier? (car p)))
                                (memq (cdr p) '(weaker stronger same)))))
              (raise-argument-error who "(listof (cons/c (or/c identifier? 'default) (or/c 'stronger 'weaker 'same)))" precedences))
            (unless (memq protocol '(automatic macro))
              (raise-argument-error who "(or/c 'automatic 'macro)" protocol))
            (unless (procedure? proc)
              (raise-argument-error who "procedure?" proc))
            (values name precedences protocol proc)))
            
(struct prefix-operator operator ())
(struct infix-operator operator (assoc)
  #:guard (lambda (name precedences protocol proc assoc who)
            (unless (memq assoc '(left right none))
              (raise-argument-error who "(or/c 'left 'right 'none)" assoc))
            (values name precedences protocol proc assoc)))

;; returns: 'stronger, 'weaker, 'same (no associativity), #f (not related)
(define (relative-precedence op other-op head)
  (define (find op-name this-op-name precs)
    (let loop ([precs precs] [default #f])
      (cond
        [(null? precs) (if (free-identifier=? op-name this-op-name)
                           'same
                           default)]
        [(eq? (caar precs) 'default) (loop (cdr precs) (cdar precs))]
        [(free-identifier=? op-name (caar precs)) (cdar precs)]
        [else (loop (cdr precs) default)])))
  (define (invert dir)
    (case dir
      [(stronger) 'weaker]
      [(weaker) 'stronger]
      [else dir]))
  (define op-name (operator-name op))
  (define other-op-name (operator-name other-op))
  (define dir1 (find other-op-name op-name (operator-precedences op)))
  (define dir2 (invert (find op-name other-op-name (operator-precedences other-op))))
  (define (raise-inconsistent how)
    (raise-syntax-error #f
                        (format
                         (string-append "inconsistent operator ~a declared\n"
                                        "  one operator: ~a\n"
                                        "  other operator: ~a")
                         how
                         (syntax-e (operator-name op))
                         (syntax-e (operator-name other-op)))
                        head))
  (when (and dir1 dir2 (not (eq? dir1 dir2)))
    (raise-inconsistent "precedence"))
  (define dir (or dir1 dir2
                  (and (free-identifier=? (operator-name op)
                                          (operator-name other-op))
                       'same)))
  (cond
    [(eq? 'same dir)
     (define op-a (infix-operator-assoc op))
     (when (infix-operator? other-op)
       (unless (eq? op-a (infix-operator-assoc other-op))
         (raise-inconsistent "associativity")))
     (case op-a
       [(left) 'weaker]
       [(right) 'stronger]
       [else 'same])]
    [else dir]))

(define (lookup-prefix-implicit alone-name adj-context in-space operator-ref operator-kind form-kind)
  (define op-stx (datum->syntax adj-context alone-name))
  (define v (syntax-local-value (in-space op-stx) (lambda () #f)))
  (define op (operator-ref v))
  (unless op
    (raise-syntax-error #f
                        (format (string-append
                                 "misplaced ~a;\n"
                                 " no infix operator is between this ~a and the previous one,\n"
                                 " and `~a` is not bound as an implicit prefix ~a")
                                form-kind form-kind
                                alone-name
                                operator-kind)
                        adj-context))
  (values v op op-stx))

(define (lookup-infix-implicit adjacent-name adj-context in-space operator-ref operator-kind form-kind)
  (define op-stx (datum->syntax adj-context adjacent-name))
  (define v (syntax-local-value (in-space op-stx) (lambda () #f)))
  (define op (operator-ref v))
  (unless op
    (raise-syntax-error #f
                        (format
                         (string-append
                          "misplaced ~a;\n"
                          " no infix operator is between this ~a and the previous one,\n"
                          " and `~a` is not bound as an implicit infix ~a")
                         form-kind form-kind
                         adjacent-name
                         operator-kind)
                        adj-context))
  (values v op op-stx))

(define (apply-prefix-direct-operator op form stx checker)
  (call-as-transformer
   stx
   (lambda (in out)
     (define proc (operator-proc op))
     (out (checker (proc (in form) stx) proc)))))

(define (apply-infix-direct-operator op form1 form2 stx checker)
  (call-as-transformer
   stx
   (lambda (in out)
     (define proc (operator-proc op))
     (checker (out (proc (in form1) (in form2) stx)) proc))))

(define (apply-prefix-transformer-operator op op-stx tail checker)
  (define proc (operator-proc op))
  (call-as-transformer
   op-stx
   (lambda (in out)
     (define-values (form new-tail) (proc (in tail)))
     (check-transformer-result (out (checker form proc))
                               (out new-tail)
                               proc))))

(define (apply-infix-transformer-operator op op-stx form1 tail checker)
  (define proc (operator-proc op))
  (call-as-transformer
   op-stx
   (lambda (in out)
     (define-values (form new-tail) (proc (in form1) (in tail)))
     (check-transformer-result (out (checker form proc))
                               (out new-tail)
                               proc))))
