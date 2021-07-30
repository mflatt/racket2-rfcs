#lang racket/base
(require syntax/parse
         syntax/stx
         enforest/proc-name)

(provide pack-tail
         unpack-tail)

(define (pack-tail tail)
  (if (stx-null? tail)
      #`(parens)
      #`(parens (group . #,tail))))

(define (unpack-tail packed-tail proc)
  (syntax-parse packed-tail
    [((~datum parens) ((~datum group) . tail)) #'tail]
    [((~datum parens)) #'()]
    [else
     (raise-result-error (if (symbol? proc) proc (proc-name proc))
                         "rhombus-syntax-list?"
                         packed-tail)]))
