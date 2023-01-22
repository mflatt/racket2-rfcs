#lang racket/base
(require "../private/bounce.rkt"
         (for-syntax
          racket/base
          (only-in "../private/parse.rkt" rhombus-definition)
          (only-in "../private/dynamic-static.rkt" use_static)))

(begin-for-syntax
  (rhombus-definition (group use_static)))

(bounce #:except (|.| #%ref #%call)
        "../meta.rkt")
(bounce-meta #:only (|.|)
             #:spaces (rhombus/impo rhombus/expo)
             "../meta.rkt")
(provide (for-syntax
          (for-space rhombus/expr
                     |.|
                     #%ref
                     #%call)
          (for-space rhombus/repet
                     |.|
                     #%ref
                     #%call)))
