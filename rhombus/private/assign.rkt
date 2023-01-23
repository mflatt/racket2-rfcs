#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest/syntax-local
                     "annotation-string.rkt")
         "binding.rkt"
         "expression.rkt")

(provide (for-space #f
                    :=)
         (for-space rhombus/bind
                    mutable))

(define-binding-syntax mutable
  (binding-transformer
   (lambda (stx)
     (syntax-parse stx
       [(_ id:identifier . new-tail)
        (values
         (binding-form
          #'mutable-info
          #'id)
         #'new-tail)]))))

(define-syntax (mutable-info stx)
  (syntax-parse stx
    [(_ static-infos id)
     (binding-info annotation-any-string
                   #'id
                   #'() ; mutable => don't claim input's static info
                   #'((id (0)))
                   #'mutable-identifier-succeed
                   #'mutable-commit
                   #'mutable-bind
                   #'[id mutable-id])]))

(define-syntax (mutable-identifier-succeed stx)
  (syntax-parse stx
    [(_ arg-id [bind-id mutable-id] IF success fail)
     #'(begin
         (define mutable-id arg-id)
         (set! mutable-id mutable-id)
         (IF #t success fail))]))

(define-syntax (mutable-commit stx)
  (syntax-parse stx
    [(_ arg-id [bind-id mutable-id])
     #'(begin)]))

(define-syntax (mutable-bind stx)
  (syntax-parse stx
    [(_ arg-id [bind-id mutable-id])
     #'(define-expression-syntax bind-id
         (mutable-variable #'mutable-id))]))

(begin-for-syntax
  (struct mutable-variable (id)
    #:property prop:rename-transformer (struct-field-index id))
  (define (mutable-variable-ref v) (and (mutable-variable? v) v)))

(define-expression-syntax :=
  (expression-infix-operator
   (expr-quote :=)
   '((default . weaker))
   'automatic
   (lambda (form1 form2 self-stx)
     (define mv (and (identifier? form1)
                     (syntax-local-value* form1 mutable-variable-ref)))
     (unless mv
       (raise-syntax-error #f
                           "left-hand argument is not a mutable identifier"
                           self-stx))
     #`(let ([#,form1 #,form2])
         (set! #,(mutable-variable-id mv) #,form1)))
   'left))
