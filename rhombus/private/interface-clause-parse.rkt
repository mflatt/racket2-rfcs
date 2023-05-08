#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     (only-in "class-parse.rkt"
                              added-method))
         "interface-clause.rkt"
         "class-clause-parse.rkt"
         (submod "class-clause-parse.rkt" for-interface)
         "parens.rkt")

(provide (for-syntax parse-annotation-options
                     parse-options
                     class-clause-accum
                     extract-internal-ids))

;; interface clause forms are defined in "class-clause-parse.rkt"

(define-for-syntax (parse-annotation-options orig-stx forms)
  (syntax-parse forms
    #:context orig-stx
    [((_ clause-parsed) ...)
     (define clauses (syntax->list #'(clause-parsed ...)))
     (let loop ([clauses clauses] [options #hasheq()])
       (cond
         [(null? clauses) options]
         [else
          (define clause (car clauses))
          (define new-options
            (syntax-parse clause
              [(#:internal id)
               (hash-set options 'internals (cons #'id (hash-ref options 'internals '())))]
              [(#:extends id ...)
               (hash-set options 'extends (append (reverse (syntax->list #'(id ...)))
                                                  (hash-ref options 'extends '())))]
              [(#:annotation block)
               (when (hash-has-key? options 'annotation-rhs)
                 (raise-syntax-error #f "multiple annotation clauses" orig-stx clause))
               (hash-set options 'annotation-rhs (extract-rhs #'block))]
              [((~or #:method #:override #:final #:final-override
                     #:property #:override-property
                     #:final-property #:final-override-property) . _)
               (hash-set options 'has-non-abstract-method? #t)]
              [(#:static-infos expr)
               (hash-set options 'static-infoss (cons #'expr (hash-ref options 'static-infoss '())))]
              [_ options]))
          (loop (cdr clauses) new-options)]))]))

(define-for-syntax (parse-options orig-stx forms)
  (syntax-parse forms
    #:context orig-stx
    [((_ clause-parsed) ...)
     (define clauses (syntax->list #'(clause-parsed ...)))
     (let loop ([clauses clauses] [options #hasheq()])
       (cond
         [(null? clauses) options]
         [else
          (define clause (car clauses))
          (define new-options
            (syntax-parse clause
              [(#:internal id) ; checked in `parse-annotation-options`
               (hash-set options 'internals (cons #'id (hash-ref options 'internals #'id)))]
              [(#:extends id ...)
               (hash-set options 'extends (append (reverse (syntax->list #'(id ...)))
                                                  (hash-ref options 'extends '())))]
              [(#:expression rhs)
               (when (hash-has-key? options 'expression-macro-rhs)
                 (raise-syntax-error #f "multiple expression macro clauses" orig-stx clause))
               (hash-set options 'expression-macro-rhs (extract-rhs #'rhs))]
              [(#:annotation block) ; checked in `parse-annotation-options`
               (hash-set options 'annotation-rhs (extract-rhs #'block))]
              [(#:dot name block)
               (hash-set options 'dots (cons (cons #'name (extract-rhs #'block))
                                             (hash-ref options 'dots null)))]
              [(#:static-infos expr)
               (hash-set options 'static-infoss (cons #'expr (hash-ref options 'static-infoss '())))]
              [_
               (parse-method-clause orig-stx options clause)]))
          (loop (cdr clauses) new-options)]))]))
