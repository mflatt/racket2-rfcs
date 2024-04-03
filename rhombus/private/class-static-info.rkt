#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     "class-parse.rkt"
                     "veneer-parse.rkt"
                     "static-info-pack.rkt")
         (submod "dot.rkt" for-dot-provider)
         "entry-point.rkt"
         (submod "define-arity.rkt" for-info)
         "indirect-static-info-key.rkt"
         "call-result-key.rkt"
         "function-arity-key.rkt"
         "function-arity.rkt"
         "dot-provider-key.rkt"
         "static-info.rkt"
         "class-able.rkt")

(provide (for-syntax extract-instance-static-infoss
                     build-instance-static-infos-defs
                     build-class-static-infos))


(define-for-syntax (extract-instance-static-infoss name-id options super interfaces private-interfaces intro)
  (define call-statinfo-indirect-id
    (able-statinfo-indirect-id 'call super interfaces name-id intro))
  (define index-statinfo-indirect-id
    (able-statinfo-indirect-id 'get super interfaces name-id intro))
  (define index-set-statinfo-indirect-id
    (able-statinfo-indirect-id 'set super interfaces name-id intro))
  (define append-statinfo-indirect-id
    (able-statinfo-indirect-id 'append super interfaces name-id intro))
  (define compare-statinfo-indirect-id
    (able-statinfo-indirect-id 'compare super interfaces name-id intro))

  (define super-call-statinfo-indirect-id
    (able-super-statinfo-indirect-id 'call super interfaces))

  (define static-infos-exprs (hash-ref options 'static-infoss '()))
  (define static-infos-id (and (pair? static-infos-exprs)
                               (intro (datum->syntax #f (string->symbol
                                                         (format "~a-statinfo" (syntax-e name-id)))))))

  (define (get-instance-static-infos internal?)
    #`(#,@(if static-infos-id
              #`((#,(quote-syntax unsyntax-splicing) (syntax-local-value (quote-syntax #,static-infos-id))))
              #'())
       #,@(if super
              (objects-desc-static-infos super)
              #'())
       #,@(apply
           append
           (for/list ([intf (in-list interfaces)]
                      #:unless (and (not internal?)
                                    (hash-ref private-interfaces intf #f)))
             (syntax->list
              (objects-desc-static-infos intf))))))

  (define instance-static-infos (get-instance-static-infos #f))
  (define internal-instance-static-infos (get-instance-static-infos #t))
    
  (define common-indirect-static-infos
    #`(#,@(if call-statinfo-indirect-id
              #`((#%indirect-static-info #,call-statinfo-indirect-id))
              #'())
       #,@(if index-statinfo-indirect-id
              #`((#%indirect-static-info #,index-statinfo-indirect-id))
              #'())
       #,@(if index-set-statinfo-indirect-id
              #`((#%indirect-static-info #,index-set-statinfo-indirect-id))
              #'())
       #,@(if append-statinfo-indirect-id
              #`((#%indirect-static-info #,append-statinfo-indirect-id))
              #'())
       #,@(if compare-statinfo-indirect-id
              #`((#%indirect-static-info #,compare-statinfo-indirect-id))
              #'())))

  (define indirect-static-infos
    #`(#,@common-indirect-static-infos
       #,@instance-static-infos))
  (define internal-indirect-static-infos
    #`(#,@common-indirect-static-infos
       #,@internal-instance-static-infos))

  (values call-statinfo-indirect-id
          index-statinfo-indirect-id
          index-set-statinfo-indirect-id
          append-statinfo-indirect-id
          compare-statinfo-indirect-id

          super-call-statinfo-indirect-id

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
                  #`(#,(quote-syntax unsyntax-splicing) (pack-static-infos 'static_info #,expr)))))))
      null))

(define-for-syntax (build-class-static-infos exposed-internal-id
                                             super
                                             given-constructor-rhs
                                             constructor-keywords constructor-defaults
                                             constructor-private-keywords constructor-private-defaults
                                             names
                                             #:veneer? [veneer? #f])
  (with-syntax ([(name constructor-name name-instance
                       internal-name-instance make-internal-name
                       indirect-static-infos
                       [name-field ...]
                       [field-static-infos ...]
                       [public-name-field/mutate ...] [public-maybe-set-name-field! ...]
                       [public-field-static-infos ...])
                 names])
    (append
     (if (syntax-e #'constructor-name)
         (list
          #`(define-static-info-syntax constructor-name
              (#%call-result ((#%dot-provider name-instance)
                              . indirect-static-infos))
              (#%function-arity #,(cond
                                    [given-constructor-rhs
                                     (syntax-parse given-constructor-rhs
                                       [(_ e-arity::entry-point-arity)
                                        (syntax->datum #'e-arity.parsed)])]
                                    [veneer? #'2]
                                    [else
                                     (summarize-arity constructor-keywords
                                                      constructor-defaults
                                                      #f #f)]))
              (#%indirect-static-info indirect-function-static-info)))
         null)
     (if (and exposed-internal-id
              (syntax-e #'make-internal-name))
         (list
          #`(define-static-info-syntax make-internal-name
              #,(let ([info #'(#%call-result ((#%dot-provider internal-name-instance)))])
                  (if super
                      ;; internal constructor is curried
                      #`(#%call-result (#,info
                                        (#%indirect-static-info indirect-function-static-info)))
                      info))
              (#%indirect-static-info indirect-function-static-info)))
         '())
     (list
      #'(begin
          (define-static-info-syntax/maybe* name-field
            (#%call-result field-static-infos)
            (#%indirect-static-info indirect-function-static-info))
          ...))
     (with-syntax ([((si ...) ...) (for/list ([maybe-set (syntax->list #'(public-maybe-set-name-field! ...))]
                                              [si (syntax->list #'(public-field-static-infos ...))])
                                     (append
                                      (if (syntax-e maybe-set)
                                          (list #`(#%call-result (#:at_arities ((2 #,si))))
                                                #'(#%function-arity 6))
                                          (list #`(#%call-result #,si)
                                                #'(#%function-arity 2)))
                                      (list #'(#%indirect-static-info indirect-function-static-info))))])
       (list
        #'(begin
            (define-static-info-syntax public-name-field/mutate si ...)
            ...))))))

(define-syntax (define-static-info-syntax/maybe* stx)
  (syntax-parse stx
    [(~or* (_ id (_ ()) . tail)
           (_ id . tail))
     #'(define-static-info-syntax id . tail)]))
