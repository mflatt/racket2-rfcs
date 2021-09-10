#lang racket/base
(require racket/keyword
         racket/symbol)

;; Writing a shubbery represented as an S-expression

(provide write-shrubbery)

(define rx:identifier #px"^(?:\\p{L}|_)(?:\\p{L}|\\p{N}|_)*$")

(define (write-shrubbery v [op (current-output-port)])
  (let loop ([v v] [sole? #t])
    (cond
      [(list? v)
       (cond
         [(null? v)
          (error 'write-shubbery "unexpected ~s" v)]
         [(eq? 'op (car v))
          (cond
            [(and (not sole?)
                  (memq (cadr v) '(... ¿)) )
             (display "¿(? " op)
             (display (cadr v) op)
             (display ")" op)]
            [else
             (display (cadr v) op)])]
         [(eq? 'alts (car v))
          (display "«" op)
          (for ([v (in-list (cdr v))])
            (display " | " op)
            (unless (and (pair? v) (eq? (car v) 'block))
              (error 'write-shubbery "unexpected ~s" v))
            (for/fold ([first? #t]) ([v (in-list (cdr v))])
              (unless first? (display "; " op))
              (loop v #f)
              #f))
          (display "»" op)]
         [(eq? 'top (car v))
          (for/fold ([first? #t]) ([v (in-list (cdr v))])
            (unless first? (display "; " op))
            (loop v #t)
            #f)
          (void)]
         [else
          (define-values (open sep close)
            (case (car v)
              [(group) (values "" " "  "")]
              [(block) (values ": «" "; " "»")]
              [(parens) (values "(" ", " ")")]
              [(brackets) (values "[" ", " "]")]
              [(braces) (values "{" ", " "}")]
              [else (error 'write-shubbery "unexpected ~s" (car v))]))
          (display open op)
          (for/fold ([first? #t]) ([v (in-list (cdr v))])
            (unless (or first?
                        (and (pair? v) (eq? (car v) 'block)))
              (display sep op))
            (loop v #f)
            #f)
          (display close op)])]
      [(symbol? v)
       (define s (symbol->immutable-string v))
       (cond
         [(regexp-match? rx:identifier s)
          (display s op)]
         [else
          (display "#{")
          (write v op)
          (display "}")])]
      [(keyword? v)
       (define s (keyword->immutable-string v))
       (cond
         [(regexp-match? rx:identifier s)
          (display "'" op)
          (display s op)
          (display "'" op)]
         [else
          (display "#{")
          (write v op)
          (display "}")])]
      [(or (string? v)
           (bytes? v)
           (exact-integer? v)
           (flonum? v))
       (write v op)]
      [(boolean? v)
       (display (if v "#true" "#false") op)]
      [else
       (display "#{")
       (write v op)
       (display "}")])))
