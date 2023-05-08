#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest/syntax-local
                     enforest/hier-name-parse
                     "class-parse.rkt"
                     (only-in "interface-parse.rkt" interface-desc-static-infos)
                     "static-info-pack.rkt")
         (submod "dot.rkt" for-dot-provider)
         "entry-point.rkt"
         "call-result-key.rkt"
         "function-arity-key.rkt"
         "function-indirect-key.rkt"
         "ref-indirect-key.rkt"
         "function-arity.rkt"
         "static-info.rkt"
         "class-able.rkt")

(provide (for-syntax extract-instance-static-infoss
                     build-instance-static-infos-defs
                     build-class-static-infos))


(define-for-syntax (extract-instance-static-infoss name-id options super interfaces private-interfaces intro)
  (define call-statinfo-indirect-id
    (able-statinfo-indirect-id 'call super interfaces name-id intro))
  (define ref-statinfo-indirect-id
    (able-statinfo-indirect-id 'ref super interfaces name-id intro))
  (define set-statinfo-indirect-id
    (able-statinfo-indirect-id 'set super interfaces name-id intro))

  (define static-infos-exprs (hash-ref options 'static-infoss '()))
  (define static-infos-id (and (pair? static-infos-exprs)
                               (intro (datum->syntax #f (string->symbol
                                                         (format "~a-statinfo" (syntax-e name-id)))))))

  (define (get-instance-static-infos internal?)
    #`(#,@(if static-infos-id
              #`((#,(quote-syntax unsyntax-splicing) (syntax-local-value (quote-syntax #,static-infos-id))))
              #'())
       #,@(if super
              (class-desc-static-infos super)
              #'())
       #,@(apply
           append
           (for/list ([intf (in-list interfaces)]
                      #:unless (and (not internal?)
                                    (hash-ref private-interfaces intf #f)))
             (syntax->list
              (interface-desc-static-infos intf))))))

  (define instance-static-infos (get-instance-static-infos #f))
  (define internal-instance-static-infos (get-instance-static-infos #t))
    
  (define common-indirect-static-infos
    #`(#,@(if call-statinfo-indirect-id
              #`((#%function-indirect #,call-statinfo-indirect-id))
              #'())
       #,@(if ref-statinfo-indirect-id
              #`((#%ref-indirect #,ref-statinfo-indirect-id))
              #'())
       #,@(if set-statinfo-indirect-id
              #`((#%set-indirect #,set-statinfo-indirect-id))
              #'())))

  (define indirect-static-infos
    #`(#,@common-indirect-static-infos
       #,@instance-static-infos))
  (define internal-indirect-static-infos
    #`(#,@common-indirect-static-infos
       #,@internal-instance-static-infos))

  (values call-statinfo-indirect-id
          ref-statinfo-indirect-id
          set-statinfo-indirect-id

          static-infos-id
          static-infos-exprs
          instance-static-infos

          indirect-static-infos
          internal-indirect-static-infos))

(define-for-syntax (build-instance-static-infos-defs static-infos-id static-infos-exprs)
  (if static-infos-id
      (list
       #`(define-syntax #,static-infos-id
           (#,(quote-syntax quasisyntax)
            (#,@(for/list ([expr (in-list (reverse static-infos-exprs))])
                  #`(#,(quote-syntax unsyntax-splicing) (pack-static-infos #,expr 'static_info)))))))
      null))

(define-for-syntax (build-class-static-infos exposed-internal-id
                                             super
                                             given-constructor-rhs
                                             constructor-keywords constructor-defaults
                                             constructor-private-keywords constructor-private-defaults
                                             names)
  (with-syntax ([(name constructor-name name-instance
                       internal-name-instance make-internal-name
                       indirect-static-infos
                       [name-field ...]
                       [field-static-infos ...])
                 names])
    (append
     (list
      #`(define-static-info-syntax constructor-name
          (#%call-result ((#%dot-provider name-instance)
                          . indirect-static-infos))
          (#%function-arity #,(if given-constructor-rhs
                                  (syntax-parse given-constructor-rhs
                                    [(_ e-arity::entry-point-arity)
                                     (syntax->datum #'e-arity.parsed)])
                                  (summarize-arity constructor-keywords
                                                   constructor-defaults
                                                   #f #f)))))
     (if exposed-internal-id
         (list
          #`(define-static-info-syntax make-internal-name
              #,(let ([info #'(#%call-result ((#%dot-provider internal-name-instance)))])
                  (if super
                      ;; internal constructor is curried
                      #`(#%call-result (#,info))
                      info))))
         '())
     (list
      #'(begin
          (define-static-info-syntax/maybe* name-field (#%call-result field-static-infos))
          ...)))))

(define-syntax (define-static-info-syntax/maybe* stx)
  (syntax-parse stx
    [(_ id (_)) #'(begin)]
    [(_ id rhs ...) #'(define-static-info-syntax id rhs ...)]))
