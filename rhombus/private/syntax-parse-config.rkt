#lang racket/base
(require "version-case.rkt")

(provide config-syntax-parse!)

;; temporarily accomodate Racket versions before `syntax/parse/report-config`
(meta-if-version-at-least
 "8.9.0.5"
 (require (rename-in syntax/parse/report-config
                     [current-report-configuration current-report-configuration]))
 (define current-report-configuration void))

(define (config-syntax-parse!)
  (current-report-configuration
   (hasheq 'literal-to-what (lambda (v)
                              '("identifier" "identifiers"))
           'literal-to-string (lambda (v)
                                (format "`~s`" (if (syntax? v)
                                                   (syntax-e v)
                                                   v)))
           'datum-to-what (lambda (v)
                            (cond
                              [(symbol? v) '("identifier" "identifiers")]
                              [(keyword? v) '("keyword" "keywords")]
                              [else '("literal" "literals")]))
           'datum-to-string (lambda (v)
                              (cond
                                [(symbol? v) (format "`~a`" (substring (format "~v" v) 2))]
                                [(keyword? v) (substring (format "~v" v) 2)]
                                [else (format "~v" v)])))))
