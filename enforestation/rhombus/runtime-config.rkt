#lang racket/base

(require racket/runtime-config
         shrubbery/parse
         shrubbery/print
         shrubbery/write)

(current-read-interaction
 (lambda (src in)
   ;; For now, read until EOF or an unindented ";" on its own line
   (define-values (i o) (make-pipe))
   (let loop ()
     (define l (read-line in))
     (unless (eof-object? l)
       (displayln l o)
       (unless (string=? l ";")
         (loop))))
   (close-output-port o)
   (port-count-lines! i)
   (define r (parse-all i #:source src))
   r))

(print-boolean-long-form #t)

(define orig-print (global-port-print-handler))

(global-port-print-handler
 (lambda (v op [mode 0])
   (cond
     [(or (string? v)
          (bytes? v)
          (exact-integer? v)
          (flonum? v)
          (boolean? v))
      (write v op)]
     [(struct? v)
      (define vec (struct->vector v))
      (write (object-name v) op)
      (display "(" op)
      (for ([i (in-range 1 (vector-length vec))])
        (unless (eqv? i 1) (display ", " op))
        (print (vector-ref vec i) op))
      (display ")" op)]
     [(list? v)
      (display "[" op)
      (for/fold ([first? #t]) ([e (in-list v)])
        (unless first? (display ", " op))
        (print e op)
        #f)
      (display "]" op)]
     [(pair? v)
      (display "cons(" op)
      (print (car v) op)
      (display ", " op)
      (print (cdr v) op)
      (display ")" op)]
     [(vector? v)
      (display "Array(" op)
      (for/fold ([first? #t]) ([e (in-vector v)])
        (unless first? (display ", " op))
        (print e op)
        #f)
      (display ")" op)]
     [(hash? v)
      (display "Map(" op)
      (for/fold ([first? #t]) ([(k v) (in-hash v)])
        (unless first? (display ", " op))
        (cond
          [(keyword? k)
           (write-shrubbery k op)
           (display ": " op)
           (print v op)]
          [else
           (print k op)
           (display ", " op)
           (print v op)])
        #f)
      (display ")" op)]
     [(syntax? v)
      (define s (syntax->datum v))
      (display "?" op)
      (when (and (pair? s)
                 (eq? 'op (car s)))
        (display " " op))
      (write-shrubbery s op)]
     [(procedure? v)
      (write v op)]
     [else
      (display "#{'" op)
      (orig-print v op 1)
      (display "}")])))

(error-syntax->string-handler
 (lambda (s len)
   (shrubbery-syntax->string s #:max-length len)))
