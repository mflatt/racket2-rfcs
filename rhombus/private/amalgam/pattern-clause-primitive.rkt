#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     "tag.rkt")
         "pattern-clause.rkt"
         "parens.rkt"
         "parse.rkt"
         "op-literal.rkt"
         (submod "equal.rkt" for-parse))

(provide (for-space rhombus/pattern_clause
                    field
                    match_def
                    match_when
                    match_unless))

(begin-for-syntax
  (define-syntax-class :field-lhs
    #:datum-literals (group)
    (pattern id:identifier
             #:with depth #'0)
    (pattern (_::brackets (group a::field-lhs) (group _::...-bind))
             #:with id #'a.id
             #:with depth #`#,(+ 1 (syntax-e #'a.depth)))))

(define-pattern-clause-syntax field
  (pattern-clause-transformer
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (op)
       [(_ field::field-lhs (tag::block in-block ...))
        #'(#:field field.id field.depth (rhombus-body-at tag in-block ...))]
       [(_ field::field-lhs _::equal rhs ...)
        #`(#:field field.id field.depth (rhombus-expression (#,group-tag rhs ...)))]))))

(define-pattern-clause-syntax match_def
  (pattern-clause-transformer
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (op)
       [(_ (~and pat (_::quotes p ...)) (tag::block in-block ...))
        #'(#:also pat (rhombus-body-at tag in-block ...))]
       [(_ (~and pat (_::quotes p ...)) _::equal rhs ...)
        #`(#:also pat (rhombus-expression (#,group-tag rhs ...)))]))))

(define-pattern-clause-syntax match_when
  (pattern-clause-transformer
   (lambda (stx)
     (syntax-parse stx
       [(_ (tag::block g ...))
        #`(#:when (rhombus-body-at tag g ...))]
       [(_ rhs ...+)
        #`(#:when (rhombus-expression (#,group-tag rhs ...)))]))))

(define-pattern-clause-syntax match_unless
  (pattern-clause-transformer
   (lambda (stx)
     (syntax-parse stx
       [(_ (tag::block g ...))
        #`(#:when (not (rhombus-body-at tag g ...)))]
       [(_ rhs ...+)
        #`(#:when (not (rhombus-expression (#,group-tag rhs ...))))]))))
