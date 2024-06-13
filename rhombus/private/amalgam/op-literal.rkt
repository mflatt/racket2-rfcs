#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest/name-parse)
         (rename-in "ellipsis.rkt"
                    [... rhombus...])
         (rename-in "underscore.rkt"
                    [_ rhombus_])
         "dollar.rkt"
         "rest-marker.rkt"
         "assign.rkt"
         "expression.rkt"
         "binding.rkt")

(provide (for-syntax
          :$ :$-expr :$-bind
          :... :...-expr :...-bind
          :_ :_-expr :_-bind
          :& :&-expr :&-bind
          :~& :~&-expr :~&-bind
          ::= ::=-expr ::=-bind))

(begin-for-syntax
  (define-syntax-rule (define-literal-class id id-expr id-bind orig-id desc)
    (begin
      (define-syntax-class (id in-space)
        #:attributes (name)
        #:description desc
        #:opaque
        [pattern ::name
                 #:when (free-identifier=? (in-space #'name)
                                           (in-space #'orig-id))])
      (define-syntax-class id-expr
        #:attributes (name)
        #:description desc
        #:opaque
        [pattern ::name
                 #:when (free-identifier=? #'name
                                           (expr-quote orig-id))])
      (define-syntax-class id-bind
        #:attributes (name)
        #:description desc
        #:opaque
        [pattern ::name
                 #:when (free-identifier=? (in-binding-space #'name)
                                           (bind-quote orig-id))])))

  (define-literal-class :$ :$-expr :$-bind $ "an escape operator")
  (define-literal-class :... :...-expr :...-bind rhombus... "an ellipsis operator")
  (define-literal-class :_ :_-expr :_-bind rhombus_ "a wildcard operator")
  (define-literal-class :& :&-expr :&-bind & "a splice operator")
  (define-literal-class :~& :~&-expr :~&-bind ~& "a keyword splice operator")
  (define-literal-class ::= ::=-expr ::=-bind := "an assignment operator"))
