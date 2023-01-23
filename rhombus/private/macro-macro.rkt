#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     (rename-in syntax/private/boundmap
                                [make-module-identifier-mapping make-free-identifier-mapping]
                                [module-identifier-mapping-get free-identifier-mapping-get]
                                [module-identifier-mapping-put! free-identifier-mapping-put!])
                     "operator-parse.rkt"
                     "consistent.rkt"
                     "syntax-class-mixin.rkt"
                     "macro-rhs.rkt"
                     "introducer.rkt"
                     (for-syntax racket/base
                                 syntax/parse/pre))
         "parse.rkt"
         "definition.rkt"
         "function.rkt"
         "name-root-ref.rkt"
         "dollar.rkt"
         ;; because we generate compile-time code:
         (for-syntax "parse.rkt")
         "op-literal.rkt"
         "binding.rkt"
         "dotted-sequence-parse.rkt"
         "parens.rkt")

(provide define-operator-definition-transformer
         define-identifier-syntax-definition-transformer
         define-identifier-syntax-definition-sequence-transformer

         (for-syntax parse-operator-definition
                     parse-operator-definitions
                     :operator-syntax-quote

                     :prefix-operator-options
                     :infix-operator-options
                     convert-prec
                     convert-assc))

(begin-for-syntax
  (define-syntax-class :op/other
    #:datum-literals (op)
    (pattern (op name))
    (pattern name:identifier)
    (pattern (~and name #:other)))

  (define-syntax-class (:keyword-matching maybe-kw)
    (pattern kw:keyword
             #:when (eq? (syntax-e #'kw) maybe-kw)))

  (define (combine-prec space-sym strongers weakers sames same-on-lefts same-on-rights)
    (define intro (space->introducer space-sym))
    (define ht (make-free-identifier-mapping))
    (define said-other? #f)
    (define prec '())
    (define (add! op kind)
      (define use-op
        (cond
          [(eq? (syntax-e op) '#:other)
           (when said-other?
             (raise-syntax-error #f
                                 "'other' multiple times in precedence specifications"
                                 op))
           (set! said-other? #t)
           op]
          [else
           (define space-op (intro op))
           (define old-op (free-identifier-mapping-get ht space-op (lambda () #f)))
           (when old-op
             (raise-syntax-error #f
                                 "operator multiple times in precedence specifications"
                                 op))
           (free-identifier-mapping-put! ht space-op space-op)
           space-op]))
      (set! prec (cons (cons use-op kind) prec)))
    (for ([stronger (in-list strongers)])
      (add! stronger 'stronger))
    (for ([weaker (in-list weakers)])
      (add! weaker 'weaker))
    (for ([same (in-list sames)])
      (add! same 'same))
    (for ([same (in-list same-on-lefts)])
      (add! same 'same-on-left))
    (for ([same (in-list same-on-rights)])
      (add! same 'same-on-right))
    (datum->syntax #f prec))

  (define-syntax-class-mixin operator-options
    #:datum-literals (op block group
                         stronger_than
                         weaker_than
                         same_as
                         same_on_left_as
                         same_on_right_as)
    (~alt (~optional (group #:stronger_than ~! (block (group stronger::op/other ...) ...))
                     #:defaults ([(stronger.name 2) '()]))
          (~optional (group #:weaker_than ~! (block (group weaker::op/other ...) ...))
                     #:defaults ([(weaker.name 2) '()]))
          (~optional (group #:same_as ~! (block (group same::op/other ...) ...))
                     #:defaults ([(same.name 2) '()]))
          (~optional (group #:same_on_left_as ~! (block (group same-on-left::op/other ...) ...))
                     #:defaults ([(same-on-left.name 2) '()]))
          (~optional (group #:same_on_right_as ~! (block (group same-on-right::op/other ...) ...))
                     #:defaults ([(same-on-right.name 2) '()])))
    #:attr prec (combine-prec space-sym
                              (syntax->list #'(stronger.name ... ...))
                              (syntax->list #'(weaker.name ... ...))
                              (syntax->list #'(same.name ... ...))
                              (syntax->list #'(same-on-left.name ... ...))
                              (syntax->list #'(same-on-right.name ... ...))))

  (define-syntax-class-mixin self-options
    #:datum-literals (op block group
                         opt_stx)
    (~alt (~optional (group #:op_stx ~! (_::block (group self-id:identifier)))
                     #:defaults ([self-id #'self]))))

  (define-composed-splicing-syntax-class (:prefix-operator-options space-sym)
    operator-options)

  (define-composed-splicing-syntax-class (:self-prefix-operator-options space-sym)
    operator-options
    self-options)
  
  (define-composed-splicing-syntax-class (:macro-prefix-operator-options space-sym)
    operator-options
    self-options)

  (define-syntax-class-mixin infix-operator-options
    #:datum-literals (op block group)
    (~alt (~optional (group #:associativity ~!
                            (block (group (~and assc
                                                (~or #:right #:left #:none)))))
                     #:defaults ([assc #'#:left]))))

  (define-composed-splicing-syntax-class (:infix-operator-options space-sym)
    operator-options
    infix-operator-options)
             
  (define-composed-splicing-syntax-class (:macro-infix-operator-options space-sym)
    operator-options
    infix-operator-options
    self-options)

  (define-syntax-class :$+1
    (pattern $-id
             #:when (free-identifier=? (bind-quote $) (in-binding-space #'$-id)
                                       (syntax-local-phase-level) (add1 (syntax-local-phase-level)))))

  (define-splicing-syntax-class :operator-or-identifier-or-$
    #:attributes (name extends)
    #:description "operator-macro pattern"
    #:datum-literals (op group)
    (pattern (~seq op-name::operator-or-identifier)
             #:when (not (free-identifier=? (in-binding-space #'op-name.name) (bind-quote $)
                                            (add1 (syntax-local-phase-level)) (syntax-local-phase-level)))
             #:attr name #'op-name.name
             #:attr extends #'#f)
    (pattern (~seq (_::parens (group seq::dotted-operator-or-identifier-sequence)))
             #:with id::dotted-operator-or-identifier #'seq
             #:attr name #'id.name
             #:attr extends #'id.extends)
    (pattern (~seq (op _::$+1) (_::parens (group (_::quotes (group (op (~and name (~datum $))))))))
             #:attr extends #'#f))

  (define-syntax-class :parsed-identifier
    #:datum-literals (group)
    (pattern id:identifier)
    (pattern (_::parens (group #:parsed id:identifier))))

  (define-splicing-syntax-class :operator-syntax-quote
    #:description "operator-macro pattern"
    #:datum-literals (op group)
    (pattern (_::quotes (~and g (group (op _::$+1) _::parsed-identifier _::operator-or-identifier-or-$ . _))))
    (pattern (_::quotes (~and g (group _::operator-or-identifier-or-$ . _)))))

  (define (convert-prec prec)
    #`(list #,@(for/list ([p (in-list (syntax->list prec))])
                 (syntax-parse p
                   [(#:other . spec) #`'(default . spec)]
                   [(op . spec) #`(cons (quote-syntax op) 'spec)]))))

  (define (convert-assc assc)
    #`'#,(string->symbol (keyword->string (syntax-e assc))))

  (define (check-parsed-right-form form-id tail-pattern)
    (syntax-parse tail-pattern
      #:datum-literals (op group)
      [((~and op-stx (op _::$+1))
        (~and parens-stx (_::parens (group #:parsed right:identifier)))
        . tail)
       (syntax-parse #'tail
         [() (void)]
         [(more . _)
          (raise-syntax-error (syntax-e form-id)
                              "no further pattern allowed after a `~parsed` escape"
                              #'more)])
       #t]
      [_ #f])))

;; parse one case (possibly the only case) in a macro definition
(define-for-syntax (parse-one-macro-definition form-id kind allowed space-sym)
  (lambda (g rhs)
    (syntax-parse g
      #:datum-literals (group op)
      ;; infix protocol
      [(group (op _::$+1) left::parsed-identifier
              op-name::operator-or-identifier-or-$
              . tail-pattern)
       (unless (memq 'infix allowed)
         (raise-syntax-error (syntax-e form-id)
                             "infix pattern is not allowed"
                             g))
       (define parsed-right? (check-parsed-right-form form-id #'tail-pattern))
       (syntax-parse rhs
         [((~and tag block) (~var opt (:macro-infix-operator-options space-sym)) rhs ...)
          #`(pre-parsed op-name.name
                        op-name.extends
                        infix
                        #,kind
                        opt
                        #,(convert-prec #'opt.prec)
                        #,(convert-assc #'opt.assc)
                        #,parsed-right?
                        [tail-pattern
                         opt.self-id
                         left.id
                         (tag rhs ...)])])]
      ;; prefix protocol
      [(group op-name::operator-or-identifier-or-$
              . tail-pattern)
       (unless (memq 'prefix allowed)
         (raise-syntax-error (syntax-e form-id)
                             "prefix pattern is not allowed"
                             g))
       (define parsed-right? (check-parsed-right-form form-id #'tail-pattern))
       (syntax-parse rhs
         [((~and tag block) (~var opt (:macro-prefix-operator-options space-sym)) rhs ...)
          #`(pre-parsed op-name.name
                        op-name.extends
                        prefix
                        #,kind
                        opt
                        #,(convert-prec #'opt.prec)
                        #f
                        #,parsed-right?
                        [tail-pattern
                         opt.self-id
                         (tag rhs ...)])])])))

(define-for-syntax (pre-parsed-name pre-parsed)
  (syntax-parse pre-parsed
    [(_ name . _) #'name]))

(define-for-syntax (pre-parsed-extends pre-parsed)
  (syntax-parse pre-parsed
    [(_ _ extends . _) #'extends]))

;; single-case macro definition:
(define-for-syntax (parse-operator-definition form-id kind g rhs space-sym compiletime-id
                                              #:allowed [allowed '(prefix infix)])
  (define p ((parse-one-macro-definition form-id kind allowed space-sym) g rhs))
  (define op (pre-parsed-name p))
  (if compiletime-id
      (build-syntax-definition/maybe-extension space-sym op
                                               (pre-parsed-extends p)
                                               #`(#,compiletime-id #,p))
      p))

;; multi-case macro definition:
(define-for-syntax (parse-operator-definitions form-id kind stx gs rhss space-sym compiletime-id
                                               #:allowed [allowed '(prefix infix)])
  (define ps (map (parse-one-macro-definition form-id kind allowed space-sym)
                  gs rhss))
  (check-consistent stx (map pre-parsed-name ps) "operator")
  (if compiletime-id
      (build-syntax-definition/maybe-extension space-sym (pre-parsed-name (car ps))
                                               (pre-parsed-extends (car ps))
                                               #`(#,compiletime-id #,stx #,@ps))
      ps))

;; An operator definition transformer involves a phase-0 binding for
;; the definition form, and a phase-1 binding for the transformer for
;; the compile-time right-hand side
(define-syntax (define-operator-definition-transformer stx)
  (syntax-parse stx
    #:literals (syntax quote)
    [(_ id
        'protocol
        space
        #'make-prefix-id
        #'make-infix-id
        #'prefix+infix-id)
     #`(begin
         (define-syntax id
           (make-operator-definition-transformer-runtime 'protocol
                                                         'space
                                                         #'compiletime-id))
         (begin-for-syntax
           (define-syntax compiletime-id
             (make-operator-definition-transformer-compiletime #'make-prefix-id
                                                               #'make-infix-id
                                                               #'prefix+infix-id
                                                               'space))))]))

(define-for-syntax (make-operator-definition-transformer-runtime protocol
                                                                 space-sym
                                                                 compiletime-id)
  (define kind protocol)
  (definition-transformer
    (lambda (stx)
      (syntax-parse (replace-head-dotted-name stx)
        #:datum-literals (group block alts op)
        [(form-id ((~and alts-tag alts) (block (group q::operator-syntax-quote
                                                      (~and rhs (block body ...))))
                                        ...+))
         (list (parse-operator-definitions #'form-id
                                           kind
                                           stx
                                           (syntax->list #'(q.g ...))
                                           (syntax->list #'(rhs ...))
                                           space-sym
                                           compiletime-id))]
        [(form-id q::operator-syntax-quote
                  (~and rhs (block body ...)))
         (list (parse-operator-definition #'form-id
                                          kind
                                          #'q.g
                                          #'rhs
                                          space-sym
                                          compiletime-id))]))))

(begin-for-syntax
  (define-for-syntax (make-operator-definition-transformer-compiletime make-prefix-id
                                                                       make-infix-id
                                                                       prefix+infix-id
                                                                       space-sym)
    (lambda (stx)
      (syntax-parse stx
        #:datum-literals (group block alts op)
        [(form-id pre-parsed)
         (parse-operator-definition-rhs #'pre-parsed
                                        space-sym
                                        make-prefix-id
                                        make-infix-id)]
        [(form-id orig-stx pre-parsed ...)
         (parse-operator-definitions-rhs #'orig-stx (syntax->list #'(pre-parsed ...))
                                         space-sym
                                         make-prefix-id
                                         make-infix-id
                                         prefix+infix-id)]))))

;; ----------------------------------------

(begin-for-syntax
  (define-syntax-class :identifier-syntax-quote
    #:datum-literals (op)
    (pattern (_::quotes g::identifier-definition-group)))

  (define-syntax-class :identifier-definition-group
    #:datum-literals (group)
    (pattern (group _:identifier . _)))
  
  (define-splicing-syntax-class :identifier-sequence-syntax-quote
    #:datum-literals (op block group)
    (pattern (_::quotes g::identifier-definition-group
                        . gs))))

(define-for-syntax (parse-transformer-definition g rhs)
  (syntax-parse g
    #:datum-literals (group)
    [(group id:identifier . tail-pattern)
     #`(pre-parsed id
                   tail-pattern
                   #,rhs)]))

(define-syntax (define-identifier-syntax-definition-transformer stx)
  (syntax-parse stx
    #:literals (syntax)
    [(_ id #:multi (space ...)
        #:extra [extra-kw extra-static-infos]
        #'make-transformer-id)
     #`(begin
         (define-syntax id (make-identifier-syntax-definition-transformer-runtime '(space ...)
                                                                                  #'compiletime-id
                                                                                  (syntax-e #'extra-kw)))
         (begin-for-syntax
           (define-syntax compiletime-id
             (make-identifier-syntax-definition-transformer-compiletime #'make-transformer-id #'extra-static-infos))))]
    [(_ id #:multi m
        #'make-transformer-id)
     #'(define-identifier-syntax-definition-transformer id #:multi m
         #:extra [#f #f]
         #'make-transformer-id)]
    [(_ id space
        #:extra extra
        #'make-transformer-id)
     #'(define-identifier-syntax-definition-transformer id #:multi (space) #:extra extra #'make-transformer-id)]
    [(_ id space
        #'make-transformer-id)
     #'(define-identifier-syntax-definition-transformer id #:multi (space) #:extra [#f #f] #'make-transformer-id)]))

(define-for-syntax (make-identifier-syntax-definition-transformer-runtime space-syms
                                                                          compiletime-id
                                                                          extra-kw)
  (definition-transformer
    (lambda (stx)
      (syntax-parse stx
        #:datum-literals (group block alts op)
        [(form-id q::identifier-syntax-quote
                  (~and rhs (tag::block
                             (~optional (group #:op_stx (_::block (group self-id:identifier)))
                                        #:defaults ([self-id #'self]))
                             (~optional (group (~var kw (:keyword-matching extra-kw)) (_::block (group extra-id:identifier)))
                                        #:defaults ([extra-id (if extra-kw #'extra #'#f)]))
                             body ...)))
         (define p (parse-transformer-definition #'q.g #'(tag body ...)))
         (define name (pre-parsed-name p))
         (list #`(define-syntaxes #,(for/list ([space-sym (in-list space-syms)])
                                      ((space->introducer space-sym) name))
                   (let ([#,name (#,compiletime-id #,p self-id extra-id)])
                     (values #,@(for/list ([space-sym (in-list space-syms)])
                                  name)))))]))))

(begin-for-syntax
  (define-for-syntax (make-identifier-syntax-definition-transformer-compiletime make-transformer-id extra-static-infos-stx)
    (lambda (stx)
      (syntax-parse stx
        [(_ pre-parsed self-id extra-argument-id)
         (parse-transformer-definition-rhs #'pre-parsed #'self-id #'extra-argument-id
                                           make-transformer-id
                                           extra-static-infos-stx)]))))

(define-syntax (define-identifier-syntax-definition-sequence-transformer stx)
  (syntax-parse stx
    #:literals (syntax)
    [(_ id space
        #'make-transformer-id)
     #`(begin
         (define-syntax id (make-identifier-syntax-definition-sequence-transformer-runtime 'space
                                                                                           #'compiletime-id))
         (begin-for-syntax
           (define-syntax compiletime-id
             (make-identifier-syntax-definition-sequence-transformer-compiletime #'make-transformer-id))))]))

(define-for-syntax (make-identifier-syntax-definition-sequence-transformer-runtime space-sym
                                                                                   compiletime-id)
  (definition-transformer
    (lambda (stx)
     (syntax-parse stx
       #:datum-literals (group block alts op)
       [(form-id q::identifier-sequence-syntax-quote
                 (~and rhs (tag::block
                            (~optional (group #:op_stx (_::block (group self-id:identifier)))
                                       #:defaults ([self-id #'self]))
                            body ...)))
        (define p (parse-transformer-definition #'q.g #'(tag body ...)))
        (list #`(define-syntax #,((space->introducer space-sym) (pre-parsed-name p))
                  (#,compiletime-id #,p q.gs self-id)))]))))

(begin-for-syntax
  (define-for-syntax (make-identifier-syntax-definition-sequence-transformer-compiletime make-transformer-id)
    (lambda (stx)
      (syntax-parse stx
        [(_ pre-parsed gs self-id)
         (parse-transformer-definition-sequence-rhs #'pre-parsed #'self-id
                                                    make-transformer-id
                                                    #'gs)]))))
