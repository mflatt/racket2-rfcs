#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         (submod "annotation.rkt" for-class))

(provide (for-space rhombus/annot
                    Maybe))

(define-annotation-syntax Maybe
  (annotation-prefix-operator
   (annot-quote Maybe)
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (parens)
       [(form-id ((~and tag parens) g) . tail)
        #:with ann::annotation #'g
        #:with ann-info::annotation-predicate-form #'ann.parsed
        (values
         (annotation-predicate-form #`(let ([pred ann-info.predicate])
                                        (lambda (v)
                                          (or (not v)
                                              (pred v))))
                                    #`())
         #'tail)]))))
