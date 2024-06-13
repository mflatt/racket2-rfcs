#lang racket/base
(require racket/keyword
         syntax/parse/pre
         "parens-sc.rkt")

(provide sort-with-respect-to-keywords)

(define (sort-with-respect-to-keywords kws unsorted-gs stx)
  (cond
    [(or (not kws)
         (for/and ([kw (in-list kws)]) (not kw)))
     unsorted-gs]
    [else
     (let loop ([gs unsorted-gs] [rev-pos-args '()] [kw-args #hasheq()])
       (cond
         [(null? gs)
          (for ([kw (in-list kws)]
                #:when kw)
            (unless (hash-ref kw-args kw #f)
              (raise-syntax-error #f
                                  (string-append "missing keyword argument `~"
                                                 (keyword->immutable-string kw)
                                                 "`")
                                  stx)))
          (for ([kw (in-hash-keys kw-args)])
            (unless (memq kw kws)
              (raise-syntax-error #f
                                  (string-append "unexpected keyword argument `~"
                                                 (keyword->immutable-string kw)
                                                 "`")
                                  stx)))
          (unless (= (length unsorted-gs) (length kws))
            (raise-syntax-error #f
                                (string-append "wrong number of by-position arguments"
                                               "\n  expected: "
                                               (number->string (- (length kws) (hash-count kw-args)))
                                               "\n  given: "
                                               (number->string (length rev-pos-args)))
                                stx))
          (let loop ([pos-args (reverse rev-pos-args)] [kws kws])
            (cond
              [(null? kws) '()]
              [(car kws) (cons (hash-ref kw-args (car kws))
                               (loop pos-args (cdr kws)))]
              [else (cons (car pos-args) (loop (cdr pos-args) (cdr kws)))]))]
         [else
          (syntax-parse (car gs)
            #:datum-literals (group)
            [(group kwd:keyword (~and blk (_::block . _)))
             (define kw (syntax-e #'kwd))
             (when (hash-ref kw-args kw #f)
               (raise-syntax-error #f
                                   (string-append "duplicate keyword argument `~"
                                                  (keyword->immutable-string kw)
                                                  "`")
                                   stx))
             (syntax-parse #'blk
               [(_ g)
                (loop (cdr gs) rev-pos-args (hash-set kw-args kw #'g))]
               [_
                (raise-syntax-error #f
                                    (string-append "expected a single group for argument after `~"
                                                   (keyword->immutable-string kw)
                                                   "`")
                                    stx)])]
            [_
             (loop (cdr gs) (cons (car gs) rev-pos-args) kw-args)])]))]))
