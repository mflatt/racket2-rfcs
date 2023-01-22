#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         "pack.rkt"
         "pattern-variable.rkt"
         "unquote-binding.rkt")

(provide (for-syntax identifier-as-unquote-binding))

(define-for-syntax (identifier-as-unquote-binding id kind
                                                  #:result [result list]
                                                  #:pattern-variable [pattern-variable list])
  (define-values (pack* unpack*)
    (case kind
      [(term) (values #'pack-term* #'unpack-term*)]
      [(group) (values #'pack-group* #'unpack-group*)]
      [(multi block) (values #'pack-tagged-multi* #'unpack-multi-as-term*)]))
  (let* ([temps (generate-temporaries (list id id))]
         [temp1 (car temps)]
         [temp2 (cadr temps)])
    (result temp1
            (list #`[#,temp2 (#,pack* (syntax #,temp1) 0)])
            (list #`[#,id (make-pattern-variable-syntaxes (quote-syntax #,id)
                                                          (quote-syntax #,temp2)
                                                          (quote-syntax #,unpack*)
                                                          0
                                                          #f
                                                          #'())])
            (list (pattern-variable (syntax-e id) id temp2 0 unpack*)))))
