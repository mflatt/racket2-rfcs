#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     "srcloc.rkt")
         "provide.rkt"
         (submod "annotation.rkt" for-class)
         "define-arity.rkt"
         "name-root.rkt"
         "function-arity-key.rkt"
         "call-result-key.rkt"
         "definition.rkt"
         "parens.rkt"
         "static-info.rkt"
         (submod "equal.rkt" for-parse)
         "dotted-sequence-parse.rkt"
         "parse.rkt"
         "call-result-key.rkt")

(provide (for-spaces (rhombus/namespace
                      rhombus/annot)
                     Parameter))

(define-for-syntax parameter-static-infos
  #`((#%function-arity 3)))

(define/arity (Parameter.make v
                              #:guard [guard #f]
                              #:name [name 'parameter])
  #:static-infos ((#%call-result #,parameter-static-infos))
  (make-parameter v guard name))

(define-name-root Parameter
  #:fields
  ([make Parameter.make]
   [def Parameter.def]))

(define-annotation-syntax Parameter
  (identifier-annotation #'parameter? parameter-static-infos))

(define-syntax Parameter.def
  (definition-transformer
    (lambda (stx)
      (syntax-parse stx
        [(_ any ...+ _::equal rhs ...+)
         (check-multiple-equals stx)
         (build-parameter-definition #'(any ...) #'(rhombus-expression (group rhs ...)))]
        [(_ any ...+ (b-tag::block g ...))
         (build-parameter-definition #'(any ...) #'(rhombus-body-at b-tag g ...))]))))

(define-for-syntax (build-parameter-definition lhs rhs)
  (with-syntax ([(name extends converter annotation-str static-infos)
                 (syntax-parse (respan lhs)
                   [(name::dotted-identifier-sequence annot::inline-annotation)
                    (syntax-parse #'name
                      [name::dotted-identifier
                       (list #'name.name #'name.extends
                             #'annot.converter #'annot.annotation-str #'annot.static-infos)])]
                   [name::dotted-identifier
                    (list #'name.name #'name.extends #f #f #'())])])
    (append
     (build-definitions/maybe-extension
      #f #'name #'extend
      #`(make-parameter #,rhs
                        #,(if (syntax-e #'converter)
                              #`(lambda (v)
                                  (converter v 'name (lambda (v who)
                                                       (raise-annotation-failure who v 'annotation-str))))
                              #f)
                        'name))
     (if (null? (syntax-e #'static-infos))
         null
         #`((define-static-info-syntax name (#%call-result static-infos)))))))

