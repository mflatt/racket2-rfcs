#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     "srcloc.rkt"
                     "statically-str.rkt"
                     "interface-parse.rkt")
         (only-in racket/vector
                  vector-append)
         "treelist.rkt"
         "provide.rkt"
         "expression.rkt"
         "repetition.rkt"
         (submod "annotation.rkt" for-class)
         "parse.rkt"
         (submod "map.rkt" for-build)
         "append-key.rkt"
         "append-property.rkt"
         "call-result-key.rkt"
         "static-info.rkt"
         (only-in "string.rkt"
                  +&)
         (submod "set.rkt" for-ref)
         (submod "set.rkt" for-build)
         "repetition.rkt"
         "compound-repetition.rkt"
         "realm.rkt"
         (only-in "class-desc.rkt" define-class-desc-syntax)
         (only-in "class-method-result.rkt" method-result)
         "is-static.rkt")

(provide (for-spaces (rhombus/class
                      rhombus/annot)
                     Appendable)
         (for-spaces (#f
                      rhombus/repet)
                     ++))

(define-values (prop:Appendable Appendable? Appendable-ref)
  (make-struct-type-property 'Appendable))

(define-annotation-syntax Appendable
  (identifier-annotation #'appendable? #'((#%append general-append))))
(define (appendable? v)
  (or (Appendable? v)
      (hash? v)
      (treelist? v)
      (list? v)
      (vector? v)
      (set? v)
      (string? v)
      (bytes? v)))

(define-class-desc-syntax Appendable
  (interface-desc #'Appendable
                  #'Appendable
                  #'()
                  #'prop:Appendable
                  #'prop:Appendable
                  #'Appendable-ref
                  '#(#&append)
                  #'#(#:abstract)
                  (hasheq 'append 0)
                  #hasheq()
                  #t
                  '()
                  #f
                  #'()
                  #f
                  '(append veneer)))

(define-for-syntax (parse-append form1 form2 self-stx form1-in
                                 static?
                                 appendable-static-info
                                 k)
  (define direct-append-id/maybe-boxed (appendable-static-info #'#%append))
  (define checked? (and direct-append-id/maybe-boxed
                        (box? (syntax-e direct-append-id/maybe-boxed))))
  (define direct-append-id (if checked?
                               (unbox (syntax-e direct-append-id/maybe-boxed))
                               direct-append-id/maybe-boxed))
  (define append-id (or direct-append-id
                        (if static?
                            (raise-syntax-error #f
                                                (string-append "specialization not known" statically-str)
                                                self-stx
                                                form1-in)
                            #'general-append)))
  (define si (or (syntax-local-static-info append-id #'#%call-result)
                 #'()))
  (k append-id
     (not checked?)
     form1 form2
     si))

(define-for-syntax (build-append append-id direct? form1 form2 orig-stxes)
  (relocate+reraw
   (respan (datum->syntax #f orig-stxes))
   (datum->syntax (quote-syntax here)
                  (if direct?
                      (list append-id form1 form2)
                      `(,#'let ([a1 ,form1]
                                [a2 ,form2])
                               (check-appendable a1 a2)
                               (,append-id a1 a2))))))

(define-syntax ++
  (expression-infix-operator
   (expr-quote ++)
   `((,(expr-quote +&) . same))
   'automatic
   (lambda (form1-in form2 self-stx)
     (define static? (is-static-context? self-stx))
     (define form1 (rhombus-local-expand form1-in))
     (parse-append
      form1 form2 self-stx form1-in
      static?
      (lambda (key) (syntax-local-static-info form1 key))
      (lambda (append-id direct? form1 form2 si)
        (wrap-static-info*
         (build-append append-id direct? form1 form2
                       (list form1-in self-stx form2))
         si))))
   'left))

(define-repetition-syntax ++
  (repetition-infix-operator
   (repet-quote ++)
   `((,(repet-quote +&) . same))
   'automatic
   (lambda (form1 form2 self-stx)
     (define static? (is-static-context? self-stx))
     (syntax-parse form1
       [form1-info::repetition-info
        (build-compound-repetition
         self-stx
         (list form1 form2)
         (lambda (form1 form2)
           (parse-append
            form1 form2 self-stx form1
            static?
            (lambda (key)
              (repetition-static-info-lookup #'form1-info.element-static-infos key))
            (lambda (append-id direct? form1 form2 si)
              (values
               (build-append append-id direct? form1 form2
                             (list form1 self-stx form2))
               si)))))]))
   'left))

;; checking for the same `append` method relies on the fact that `class`
;; will generate a new procedure each time that `append` is overridden
(define (same-append? a b)
  (eq? a b))

(define (general-append map1 map2)
  (define (mismatch what)
    (raise-arguments-error* '++ rhombus-realm
                            (format "cannot append a~a ~a and other value"
                                    (if (eqv? (string-ref what 0) #\a) "n" "")
                                    what)
                            what map1
                            "other value" map2))
  (cond
    [(treelist? map1) (cond
                        [(treelist? map2) (treelist-append map1 map2)]
                        [else (mismatch "List")])]
    [(list? map1) (cond
                    [(list? map2) (append map1 map2)]
                    [else (mismatch "PairList")])]
    [(hash? map1) (cond
                    [(hash? map2) (hash-append/proc map1 map2)]
                    [else (mismatch "Map")])]
    [(set? map1) (cond
                   [(set? map2) (set-append/proc map1 map2)]
                   [else (mismatch "Set")])]
    [(string? map1) (cond
                      [(string? map2) (string-append-immutable map1 map2)]
                      [else (mismatch "String")])]
    [(bytes? map1) (cond
                     [(bytes? map2) (bytes-append map1 map2)]
                     [else (mismatch "Bytes" map1)])]
    [(appendable-ref map1 #f)
     => (lambda (app1)
          (cond
            [(appendable-ref map2 #f)
             => (lambda (app2)
                  (cond
                    [(same-append? app1 app2)
                     (app1 map1 map2)]
                    [else
                     (mismatch "appendable object")]))]
            [else (mismatch "appendable object")]))]
    [(vector? map1) (cond
                     [(vector? map2) (vector-append map1 map2)]
                     [else (mismatch "array")])]    
    [else (raise-argument-error* '++ rhombus-realm "Appendable" map1)]))

(define (check-appendable a1 a2)
  (cond
    [(appendable-ref a1 #f)
     => (lambda (app1)
          (unless (cond
                    [(appendable-ref a2 #f)
                     => (lambda (app2)
                          (same-append? app1 app2))]
                    [else #f])
            (raise-arguments-error* '++ rhombus-realm
                                    "cannot append an appendable object and other value"
                                    "appendable object" a1
                                    "other value" a2)))]
    [else
     ;; If we get here, then it means that static information was wrong
     (raise-argument-error* '++ rhombus-realm "Appendable" a1)]))
