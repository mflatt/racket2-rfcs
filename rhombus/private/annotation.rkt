#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     syntax/stx
                     shrubbery/print
                     enforest
                     enforest/operator
                     enforest/syntax-local
                     enforest/property
                     enforest/proc-name
                     enforest/name-parse
                     enforest/operator
                     "srcloc.rkt"
                     "name-path-op.rkt"
                     "pack.rkt"
                     "introducer.rkt"
                     "annotation-string.rkt"
                     "realm.rkt"
                     "keyword-sort.rkt")
         "annotation-operator.rkt"
         "definition.rkt"
         "expression.rkt"
         "binding.rkt"
         "expression+binding.rkt"
         "name-root.rkt"
         "name-root-ref.rkt"
         "static-info.rkt"
         "parse.rkt"
         "realm.rkt")

(provide (for-space rhombus/expr
                    ::
                    -:
                    is_a)
         (for-space rhombus/bind
                    ::
                    -:)
         (for-space rhombus/annot

                    Any
                    Boolean
                    Integer
                    PositiveInteger
                    NegativeInteger
                    NonnegativeInteger
                    Number
                    Real
                    String
                    Bytes
                    Symbol
                    Keyword
                    Void

                    matching
                    #%parens
                    #%literal))

(module+ for-class
  (begin-for-syntax
    (provide (property-out annotation-prefix-operator)
             (property-out annotation-infix-operator)

             identifier-annotation
             
             in-annotation-space

             check-annotation-result

             :annotation
             :annotation-form
             :inline-annotation
             :unparsed-inline-annotation
             :annotation-infix-op+form+tail

             annotation-form

             parse-annotation-of))
  
  (provide define-annotation-syntax
           define-annotation-constructor

           raise-annotation-failure))

(begin-for-syntax
  ;; see also "annotation-property.rkt"

  (property annotation (predicate-stx static-infos))

  (define in-annotation-space (make-interned-syntax-introducer/add 'rhombus/annot))

  (define (raise-not-a-annotation id)
    (raise-syntax-error #f
                        "not bound as an annotation"
                        id))

  (define (check-annotation-result stx proc)
    (unless (and (syntax? stx)
                 (let ([l (syntax->list stx)])
                   (and l
                        (= (length l) 2))))
      (raise-result-error* (proc-name proc)
                           rhombus-realm
                           "Annotation_Syntax"
                           stx))
    stx)

  (define-enforest
    #:enforest enforest-annotation
    #:syntax-class :annotation
    #:infix-more-syntax-class :annotation-infix-op+form+tail
    #:desc "annotation"
    #:operator-desc "annotation operator"
    #:in-space in-annotation-space
    #:name-path-op name-path-op
    #:name-root-ref name-root-ref
    #:name-root-ref-root name-root-ref-root
    #:prefix-operator-ref annotation-prefix-operator-ref
    #:infix-operator-ref annotation-infix-operator-ref
    #:check-result check-annotation-result
    #:make-identifier-form raise-not-a-annotation)

  (define-syntax-class :annotation-seq
    (pattern stxes
             #:with (~var c (:annotation-infix-op+form+tail #'::)) #'(group . stxes)
             #:attr parsed #'c.parsed
             #:attr tail #'c.tail))

  (define-splicing-syntax-class :inline-annotation
    (pattern (~seq op::name ctc ...)
             #:do [(define check? (free-identifier=? (in-binding-space #'op.name) (bind-quote ::)))]
             #:when (or check?
                        (free-identifier=? (in-binding-space #'op.name) (bind-quote -:)))
             #:with c::annotation #'(group ctc ...)
             #:with c-parsed::annotation-form #'c.parsed
             #:attr predicate (if check? #'c-parsed.predicate #'#f)
             #:attr annotation-str (datum->syntax #f (shrubbery-syntax->string #'(ctc ...)))
             #:attr static-infos #'c-parsed.static-infos))

  (define-splicing-syntax-class :unparsed-inline-annotation
    #:attributes (seq)
    (pattern (~seq o::name ctc ...)
             #:when (or (free-identifier=? (in-binding-space #'op.name) (bind-quote ::))
                        (free-identifier=? (in-binding-space #'op.name) (bind-quote -:)))
             #:attr seq #'(o ctc ...))
    (pattern (~seq (~and o (op -:)) ctc ...)
             #:attr seq #'(o ctc ...)))

  (define-syntax-class :annotation-form
    (pattern (predicate static-infos)))

  (define (annotation-form predicate static-infos)
    #`(#,predicate #,static-infos))
  
  (define (identifier-annotation name predicate-stx static-infos)
    (define packed #`(#,predicate-stx #,static-infos))
    (annotation-prefix-operator
     name
     '((default . stronger))
     'macro
     (lambda (stx)
       (values packed (syntax-parse stx
                        [(_ . tail) #'tail]
                        [_ 'does-not-happen])))))
  
  (define (parse-annotation-of stx predicate-stx static-infos
                               sub-n kws predicate-maker info-maker)
    (syntax-parse stx
      #:datum-literals (parens)
      [(form-id ((~and tag parens) g ...) . tail)
       (define unsorted-gs (syntax->list #'(g ...)))
       (unless (= (length unsorted-gs) sub-n)
         (raise-syntax-error #f
                             "wrong number of subannotations in parentheses"
                             #'(form-id (tag g ...))))
       (define gs (sort-with-respect-to-keywords kws unsorted-gs stx))
       (define c-parseds (for/list ([g (in-list gs)])
                           (syntax-parse g
                             [c::annotation #'c.parsed])))
       (define c-predicates (for/list ([c-parsed (in-list c-parseds)])
                              (syntax-parse c-parsed
                                [c::annotation-form #'c.predicate])))
       (define c-static-infoss (for/list ([c-parsed (in-list c-parseds)])
                                 (syntax-parse c-parsed
                                   [c::annotation-form #'c.static-infos])))
       (values (annotation-form #`(lambda (v)
                                    (and (#,predicate-stx v)
                                         #,(predicate-maker #'v c-predicates)))
                                #`(#,@(info-maker c-static-infoss)
                                   . #,static-infos))
               #'tail)]))
     
  (define (annotation-constructor name predicate-stx static-infos
                                  sub-n kws predicate-maker info-maker
                                  parse-annotation-of)
    (values
     ;; root
     (annotation-prefix-operator
      name
      '((default . stronger))
      'macro
      (lambda (stx)
        (syntax-parse stx
          [(_ . tail)
           (values (annotation-form predicate-stx
                                    static-infos)
                   #'tail)])))
     ;; `of`:
     (annotation-prefix-operator
      name
      '((default . stronger))
      'macro
      (lambda (stx)
        (parse-annotation-of (replace-head-dotted-name stx)
                             predicate-stx static-infos
                             sub-n kws predicate-maker info-maker)))))

  (define (annotation-of-constructor name predicate-stx static-infos
                                     sub-n kws predicate-maker info-maker
                                     parse-annotation-of)
    (annotation-prefix-operator
      name
      '((default . stronger))
      'macro
      (lambda (stx)
        (syntax-parse stx
          #:datum-literals (op |.| parens of)
          [(form-id (op |.|) (~and of-id of) . tail)
           (parse-annotation-of #`(of-id . tail)
                                predicate-stx static-infos
                                sub-n kws predicate-maker info-maker)]
          [(form-id (op |.|) other:identifier . tail)
           (raise-syntax-error #f
                               "field not provided by annotation"
                               #'form-id
                               #'other)]
          [(_ . tail)
           ;; we don't get here when used specifically as `of`
           (values (annotation-form predicate-stx
                                    static-infos)
                   #'tail)])))))

(define-syntax (define-annotation-constructor stx)
  (syntax-parse stx
    [(_ name
        binds
        predicate-stx static-infos
        sub-n kws predicate-maker info-maker
        (~optional (~seq #:parse-of parse-annotation-of-id)
                   #:defaults ([parse-annotation-of-id #'parse-annotation-of])))
     (cond
       [(eq? (syntax-local-context) 'module)
        #'(begin
            (begin-for-syntax
              (define-values (root-proc of-proc)
                (let binds
                    (annotation-constructor #'name predicate-stx static-infos
                                            sub-n 'kws predicate-maker info-maker
                                            parse-annotation-of-id))))
            (define-name-root name
              #:space rhombus/annot
              #:fields (of)
              #:root root-proc)
            (define-syntax of of-proc))]
       [else
        ;; internal definition context cannot bind portal syntax
        #`(define-syntax #,(in-annotation-space #'name)
            (let binds
                (annotation-of-constructor #'name predicate-stx static-infos
                                           sub-n 'kws predicate-maker info-maker
                                           parse-annotation-of-id)))])]))

(define-for-syntax (make-annotation-apply-expression-operator name checked?)
  (expression-infix-operator
   (in-expression-space name)
   `((default . weaker))
   'macro
   (lambda (form tail)
     (syntax-parse tail
       [(op . t::annotation-seq)
        #:with c-parsed::annotation-form #'t.parsed
        (values
         (wrap-static-info*
          (if checked?
              #`(let ([val #,form])
                  (if (c-parsed.predicate val)
                      val
                      (raise-::-annotation-failure val '#,(shrubbery-syntax->string #'t))))
              form)
          #'c-parsed.static-infos)
         #'t.tail)]))
   'none))

(define-for-syntax (make-annotation-apply-binding-operator name checked?)
  (binding-infix-operator
   (in-binding-space name)
   `((default . weaker))
   'macro
   (lambda (form tail)
     (syntax-parse tail
       [(op . t::annotation-seq)
        #:with c-parsed::annotation-form #'t.parsed
        #:with left::binding-form form
        (values
         (binding-form
          #'annotation-infoer
          #`(#,(shrubbery-syntax->string #'t)
             #,(and checked? #'c-parsed.predicate)
             c-parsed.static-infos
             left.infoer-id
             left.data))
         #'t.tail)]))
   'none))

(define-expression-syntax ::
  (make-annotation-apply-expression-operator #':: #t))
(define-binding-syntax ::
  (make-annotation-apply-binding-operator #':: #t))

(define-expression-syntax -:
  (make-annotation-apply-expression-operator #'-: #f))
(define-binding-syntax -:
  (make-annotation-apply-binding-operator #'-: #f))

(define-expression-syntax is_a
  (expression-infix-operator
   (in-expression-space #'is_a)
   '((default . weaker))
   'macro
   (lambda (form tail)
     (syntax-parse tail
       [(op . t::annotation-seq)
        #:with c-parsed::annotation-form #'t.parsed
        (values
         #`(c-parsed.predicate #,form)
         #'t.tail)]))
   'none))

(define-syntax (annotation-infoer stx)
  (syntax-parse stx
    [(_ static-infos (annotation-str predicate (static-info ...) left-infoer-id left-data))
     #:with left-impl::binding-impl #'(left-infoer-id (static-info ... . static-infos) left-data)
     #:with left::binding-info #'left-impl.info
     (if (syntax-e #'predicate)
         (binding-info (annotation-string-and (syntax-e #'left.annotation-str) (syntax-e #'annotation-str))
                       #'left.name-id
                       #'left.static-infos
                       #'left.bind-infos
                       #'check-predicate-matcher
                       #'commit-nothing-new
                       #'bind-nothing-new
                       #'(predicate left.matcher-id left.committer-id left.binder-id left.data))
         #'left)]))

(define-syntax (check-predicate-matcher stx)
  (syntax-parse stx
    [(_ arg-id (predicate left-matcher-id left-committer-id left-binder-id left-data) IF success fail)
     #'(IF (predicate arg-id)
           (left-matcher-id
            arg-id
            left-data
            IF
            success
            fail)
           fail)]))

(define-syntax (commit-nothing-new stx)
  (syntax-parse stx
    [(_ arg-id (predicate left-matcher-id left-committer-id left-binder-id left-data))
     #'(left-committer-id arg-id left-data)]))

(define-syntax (bind-nothing-new stx)
  (syntax-parse stx
    [(_ arg-id (predicate left-matcher-id left-committer-id left-binder-id left-data))
     #'(left-binder-id arg-id left-data)]))

(define-syntax (define-annotation-syntax stx)
  (syntax-parse stx
    [(_ id:identifier rhs)
     #`(define-syntax #,(in-annotation-space #'id)
         rhs)]))

(define-annotation-syntax Any (identifier-annotation #'Any #'(lambda (x) #t) #'()))
(define-annotation-syntax Boolean (identifier-annotation #'Boolean #'boolean? #'()))
(define-annotation-syntax Integer (identifier-annotation #'Integer #'exact-integer? #'()))
(define-annotation-syntax PositiveInteger (identifier-annotation #'PositiveInteger #'exact-positive-integer? #'()))
(define-annotation-syntax NegativeInteger (identifier-annotation #'NegativeInteger #'exact-negative-integer? #'()))
(define-annotation-syntax NonnegativeInteger (identifier-annotation #'NonnegativeInteger #'exact-nonnegative-integer? #'()))
(define-annotation-syntax Number (identifier-annotation #'Number #'number? #'()))
(define-annotation-syntax Real (identifier-annotation #'Real #'real? #'()))
(define-annotation-syntax String (identifier-annotation #'String #'string? #'()))
(define-annotation-syntax Bytes (identifier-annotation #'Bytes #'bytes? #'()))
(define-annotation-syntax Symbol (identifier-annotation #'Symbol #'symbol? #'()))
(define-annotation-syntax Keyword (identifier-annotation #'Keyword #'keyword? #'()))
(define-annotation-syntax Void (identifier-annotation #'Void #'void? #'()))

;; not exported, but referenced by `:annotation-seq` so that
;; annotation parsing terminates appropriately
(define-annotation-syntax ::
  (annotation-infix-operator
   #'::
   `((default . stronger))
   'macro
   (lambda (stx) (error "should not get here"))
   'none))

(define (raise-::-annotation-failure val ctc)
  (raise-annotation-failure ':: val ctc))

(define (raise-annotation-failure who val ctc)
  (raise
   (exn:fail:contract
    (error-message->adjusted-string
     who
     rhombus-realm
     (format
      (string-append "value does not satisfy annotation\n"
                     "  argument: ~v\n"
                     "  annotation: ~a")
      val
      (error-contract->adjusted-string
       ctc
       rhombus-realm))
     rhombus-realm)
    (current-continuation-marks))))

(define-annotation-syntax matching
  (annotation-prefix-operator
   #'matching
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (parens)
       [(_ (parens arg::binding) . tail)
        #:with arg-parsed::binding-form #'arg.parsed
        #:with arg-impl::binding-impl #'(arg-parsed.infoer-id () arg-parsed.data)
        #:with arg-info::binding-info #'arg-impl.info
        (values
         #`((lambda (arg-info.name-id)
              (arg-info.matcher-id arg-info.name-id
                                   arg-info.data
                                   if/blocked
                                   #t
                                   #f))
            arg-info.static-infos)
         #'tail)]))))

(define-syntax-rule (if/blocked tst thn els)
  (if tst (let () thn) els))

(define-annotation-syntax #%parens
  (annotation-prefix-operator
   #'%parens
   '((default . stronger))
   'macro
   (lambda (stxes)
     (syntax-parse stxes
       [(_ (~and head ((~datum parens) . args)) . tail)
        (let ([args (syntax->list #'args)])
          (cond
            [(null? args)
             (raise-syntax-error #f "empty annotation" #'head)]
            [(pair? (cdr args))
             (raise-syntax-error #f "too many annotations" #'head)]
            [else
             (syntax-parse (car args)
               [c::annotation (values #'c.parsed #'tail)])]))]))))

(define-annotation-syntax #%literal
  (annotation-prefix-operator
   #'%literal
   '((default . stronger))
   'macro
   (lambda (stxes)
     (syntax-parse stxes
       [(_ . tail)
        (raise-syntax-error #f
                            "literal not allowed as an annotation"
                            #'tail)]))))
