#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     shrubbery/print
                     "srcloc.rkt")
         syntax/parse/pre
         "parse.rkt"
         "expression.rkt"
         "binding.rkt"
         (submod "syntax-class-primitive.rkt" for-quasiquote)
         "dollar.rkt"
         "repetition.rkt"
         "static-info.rkt"
         (submod "syntax-object.rkt" for-quasiquote))

(provide (for-syntax make-pattern-variable-bind
                     deepen-pattern-variable-bind
                     extract-pattern-variable-bind-id-and-depth))

(define-for-syntax (make-pattern-variable-bind name-id temp-id unpack* depth splice? attrib-lists)
  (define no-repetition?
    (and (eqv? 0 depth)
         (for/and ([a (in-list attrib-lists)])
           (eqv? 0 (pattern-variable-depth (list->pattern-variable a))))))
  (define ids (if no-repetition?
                  (list name-id)
                  (list (in-expression-space name-id) (in-repetition-space name-id))))
  #`[#,ids (make-pattern-variable-syntaxes
             (quote-syntax #,name-id)
             (quote-syntax #,temp-id)
             (quote-syntax #,unpack*)
             #,depth
             #,splice?
             (quote-syntax #,attrib-lists)
             #,no-repetition?)])

(define-for-syntax (deepen-pattern-variable-bind sidr)
  (syntax-parse sidr
    [(ids (make-pattern-variable-syntaxes self-id temp-id unpack* depth splice? attrs expr?))
     (define new-ids
       (syntax-parse #'ids
         [(id) #`(#,(in-expression-space #'id) #,(in-repetition-space #'id))]
         [_ #'ids]))
     #`(#,new-ids (make-pattern-variable-syntaxes self-id temp-id unpack* #,(add1 (syntax-e #'depth)) splice? attrs #f))]))

(define-for-syntax (extract-pattern-variable-bind-id-and-depth sids sid-ref)
  (list (car (syntax-e sids))
        (syntax-parse sid-ref
          [(make-pattern-variable-syntaxes _ _ _ depth . _) #'depth])))

(define-for-syntax (make-pattern-variable-syntaxes name-id temp-id unpack* depth splice? attributes no-repetition?)
  (define (lookup-attribute stx var-id attr-id want-repet?)
    (define attr (for/or ([var (in-list (syntax->list attributes))])
                   (and (eq? (syntax-e attr-id) (syntax-e (car (syntax-e var))))
                        (syntax-list->pattern-variable var))))
    (unless (and attr (eq? want-repet? (not (eqv? 0 (+ depth
                                                       (if splice? -1 0)
                                                       (pattern-variable-depth attr))))))
      (raise-syntax-error #f
                          (format
                           (string-append (if attr
                                              (if want-repet?
                                                  "attribute is not a repetition\n"
                                                  "attribute is a repetition\n")
                                              "attribute not found\n")
                                          "  pattern: ~a\n"
                                          "  attribute: ~a")
                           (syntax-e var-id)
                           (syntax-e attr-id))
                          stx))
    attr)
  (define expr-handler
    (lambda (stx fail)
      (syntax-parse stx
        #:datum-literals (op |.|)
        [(var-id (op |.|) attr-id . tail)
         (define attr (lookup-attribute stx #'var-id #'attr-id #f))
         (values (wrap-static-info* (pattern-variable-val-id attr)
                                    syntax-static-infos)
                 #'tail)]
        [_
         (if (eqv? depth 0)
             (id-handler stx)
             (fail))])))
  (define id-handler
    (lambda (stx)
      (syntax-parse stx
        [(_ . tail) (values (wrap-static-info* temp-id syntax-static-infos) #'tail)])))
  (cond
    [no-repetition?
     (if (null? (syntax-e attributes))
         (expression-transformer
          id-handler)
         (expression-transformer
          (lambda (stx)
            (expr-handler stx
                          (lambda ()
                            (id-handler stx))))))]
    [else (make-expression+repetition
           name-id
           #`(#,unpack* #'$ #,temp-id #,depth)
           syntax-static-infos
           #:depth depth
           #:repet-handler (lambda (stx next)
                             (syntax-parse stx
                               #:datum-literals (op |.|)
                               [(var-id (~and dot-op (op |.|)) attr-id . tail)
                                (define attr (lookup-attribute stx #'var-id #'attr-id #t))
                                (define var-depth (+ (pattern-variable-depth attr) depth (if splice? -1 0)))
                                (values (make-repetition-info #'(var-id dot-op attr-id)
                                                              (string->symbol
                                                               (format "~a.~a" (syntax-e #'var-id) (syntax-e #'attr-id)))
                                                              #`(#,(pattern-variable-unpack*-id attr)
                                                                 #'$
                                                                 #,(pattern-variable-val-id attr)
                                                                 #,var-depth)
                                                              var-depth
                                                              #'0
                                                              syntax-static-infos
                                                              #f)
                                        #'tail)]
                               [_ (next)]))
           #:expr-handler expr-handler)]))
