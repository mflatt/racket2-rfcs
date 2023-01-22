#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         "provide.rkt"
         "expression.rkt"
         "binding.rkt"
         "reducer.rkt"
         "parse.rkt"
         "static-info.rkt"
         "function-arity-key.rkt"
         (submod "equal.rkt" for-parse))

(provide (for-spaces (rhombus/expr
                      rhombus/bind
                      rhombus/reducer
                      rhombus/statinfo)
                     values))

(define-expression values values)

(define-binding-syntax values
  (binding-prefix-operator
   #'values
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       [(head . _)
        (raise-syntax-error #f
                            (string-append "not allowed as a pattern (except as a non-nested"
                                           " pattern by forms that specifically recognize it)")
                            #'head)]))))

(define-reducer-syntax values
  (reducer-transformer
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (group op)
       [(_ (parens (group id:identifier _::equal rhs ...) ...))
        (with-syntax ([(id ...) (in-expression-space #'(id ...))])
          #'[begin
              ([id (rhombus-expression (group rhs ...))] ...)
              (begin)
              ()])]))))

(define-static-info-syntax values
  (#%function-arity -1))
