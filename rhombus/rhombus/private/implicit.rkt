#lang racket/base
(require (for-syntax racket/base
                     syntax/parse
                     "srcloc.rkt")
         "expression.rkt"
         "binding.rkt"
         "expression+binding.rkt"
         "parse.rkt"
         (submod "function.rkt" for-call))

(provide #%block
         #%literal
         #%tuple
         #%call)

(define-syntax #%block
  (expression-prefix-operator
   #'%block
   '((default . stronger))
   'macro
   (lambda (stxes)
     (syntax-parse stxes
       [(_ (~and head ((~and tag (~datum block)) . body)) . tail)
        (values (quasisyntax/loc #'tag (rhombus-block . body))
                #'tail)]))))

(define-syntax #%literal
  (make-expression+binding-prefix-operator
   #'%literal
   '((default . stronger))
   'macro
   (lambda (stxes)
     (syntax-parse stxes
       [(_ datum . tail)
        (when (keyword? (syntax-e #'datum)) (raise-keyword-error #'datum))
        (values (syntax/loc #'datum (quote datum))
                #'tail)]))
   (lambda (stxes)
     (syntax-parse stxes
       [(_ datum . tail)
        (when (keyword? (syntax-e #'datum)) (raise-keyword-error #'datum))
        (values (binding-form #'literal
                              #'literal-matcher
                              #'literal-bind-nothing
                              #'datum)
                #'tail)]))))

(define-syntax (literal-matcher stx)
  (syntax-parse stx
    [(_ arg-id datum IF success fail)
     #'(IF (equal? arg-id (quote datum))
           success
           fail)]))

(define-syntax (literal-bind-nothing stx)
  (syntax-parse stx
    [(_ arg-id datum)
     #'(begin)]))

(define-for-syntax (raise-keyword-error datum)
  (raise-syntax-error #f
                      "misplaced keyword"
                      datum))

(define-syntax #%tuple
  (make-expression+binding-prefix-operator
   #'%tuple
   '((default . stronger))
   'macro
   (lambda (stxes)
     (syntax-parse stxes
       [(_ (~and head ((~datum parens) . args)) . tail)
        (let ([args (syntax->list #'args)])
          (cond
            [(null? args)
             (raise-syntax-error #f "empty expression" #'head)]
            [(pair? (cdr args))
             (raise-syntax-error #f "too many expressions" #'head)]
            [else
             ;; eagerly parse content of parentheses; we could choose to
             ;; delay parsing by using `rhombus-expression`, instead
             (syntax-parse (car args)
               [e::expression (values #'e.parsed #'tail)])]))]))
   (lambda (stxes)
     (syntax-parse stxes
       [(_ (~and head ((~datum parens) . args)) . tail)
        (let ([args (syntax->list #'args)])
          (cond
            [(null? args)
             (raise-syntax-error #f "empty pattern" #'head)]
            [(pair? (cdr args))
             (raise-syntax-error #f "too many patterns" #'head)]
            [else
             (syntax-parse (car args)
               [b::binding (values #'b.parsed #'tail)])]))]))))

(define-syntax #%call
  (expression-infix-operator
   #'%call
   '((default . stronger))
   'macro
   (lambda (rator stxes)
     (parse-function-call rator stxes))
   'left))
