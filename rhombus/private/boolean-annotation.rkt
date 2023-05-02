#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     "with-syntax.rkt"
                     "annotation-string.rkt")
         "annotation.rkt"
         (submod "annotation.rkt" for-class)
         "static-info.rkt"
         "parse.rkt")

(provide (for-space rhombus/annot
                    &&
                    \|\|))

(define-annotation-syntax &&
  (annotation-infix-operator
   (annot-quote &&)
   (list (cons (annot-quote \|\|) 'stronger))
   'automatic
   (lambda (lhs rhs stx)
     (with-syntax-parse ([l::annotation-predicate-form lhs]
                         [r::annotation-predicate-form rhs]
                         [(r-static-info ...) #'r.static-infos])
       #`((let ([l-pred l.predicate]
                [r-pred r.predicate])
            (lambda (v)
              (and (l-pred v) (r-pred v))))
          (r-static-info ... . l.static-infos))))
   'left))

(define-annotation-syntax \|\|
  (annotation-infix-operator
   (annot-quote \|\|)
   null
   'automatic
   (lambda (lhs rhs stx)
     (with-syntax-parse ([l::annotation-predicate-form lhs]
                         [r::annotation-predicate-form rhs]
                         [(l-static-info ...) #'l.static-infos])
       #`((let ([l-pred l.predicate]
                [r-pred r.predicate])
            (lambda (v)
              (or (l-pred v) (r-pred v))))
          #,(static-infos-intersect #'l.static-infos #'r.static-infos))))
   'left))
