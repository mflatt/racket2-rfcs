#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         "provide.rkt"
         "placeholder.rkt")

(provide (for-spaces (rhombus/expr
                      rhombus/bind)
                     $
                     $&))

(define-placeholder-syntax $
  "misuse outside of a template"
  "misuse outside of a pattern")

(define-placeholder-syntax $&
  "misuse outside of a template"
  "misuse outside of a pattern")
