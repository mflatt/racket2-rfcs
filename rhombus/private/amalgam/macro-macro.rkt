#lang racket/base
(require (for-syntax racket/base
                     racket/keyword
                     syntax/parse/pre
                     (rename-in syntax/private/boundmap
                                [make-module-identifier-mapping make-free-identifier-mapping]
                                [module-identifier-mapping-get free-identifier-mapping-get]
                                [module-identifier-mapping-put! free-identifier-mapping-put!])
                     enforest/name-parse
                     "consistent.rkt"
                     "syntax-class-mixin.rkt"
                     "macro-rhs.rkt"
                     "introducer.rkt"
                     (for-syntax racket/base
                                 syntax/parse/pre))
         "definition.rkt"
         "name-root-ref.rkt"
         "dollar.rkt"
         "binding.rkt"
         (only-in "unquote-binding-primitive.rkt"
                  #%parens)
         "unquote-binding.rkt"
         "dotted-sequence-parse.rkt"
         "parens.rkt")

(provide define-operator-definition-transformer
         define-identifier-syntax-definition-transformer
         define-identifier-syntax-definition-sequence-transformer

         (for-syntax parse-operator-definition
                     parse-operator-definitions
                     parse-identifier-syntax-transformer
                     :operator-syntax-quote

                     :prefix-operator-options
                     :infix-operator-options
                     :postfix-operator-options
                     :all-operator-options
                     convert-prec
                     convert-assc))

(begin-for-syntax
  (define-syntax-class :op/other
    #:datum-literals (op)
    (pattern (op name))
    (pattern name:identifier)
    (pattern (~and name #:other)))

  (define-syntax-class (:keyword-matching kws)
    (pattern kw:keyword
             #:when (memq (syntax-e #'kw) kws)))

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

  (define-splicing-syntax-class :ops/others
    #:description "operator, identifier, or `~other`"
    #:opaque
    #:attributes ([name 1])
    (pattern (_::block (group o::op/other ...) ...)
             #:with (name ...) #'(o.name ... ...))
    (pattern (~seq ::op/other ...)))

  (define-syntax-class-mixin operator-options
    #:datum-literals (op group
                         stronger_than
                         weaker_than
                         same_as
                         same_on_left_as
                         same_on_right_as)
    (~alt (~optional (group #:stronger_than ~! stronger::ops/others)
                     #:defaults ([(stronger.name 2) '()]))
          (~optional (group #:weaker_than ~! weaker::ops/others)
                     #:defaults ([(weaker.name 2) '()]))
          (~optional (group #:same_as ~! same::ops/others)
                     #:defaults ([(same.name 2) '()]))
          (~optional (group #:same_on_left_as ~! same-on-left::ops/others)
                     #:defaults ([(same-on-left.name 2) '()]))
          (~optional (group #:same_on_right_as ~! same-on-right::ops/others)
                     #:defaults ([(same-on-right.name 2) '()])))
    #:with prec (combine-prec space-sym
                              (syntax->list #'(stronger.name ...))
                              (syntax->list #'(weaker.name ...))
                              (syntax->list #'(same.name ...))
                              (syntax->list #'(same-on-left.name ...))
                              (syntax->list #'(same-on-right.name ...))))

  (define-syntax-class-mixin self-options
    #:datum-literals (group)
    (~alt (~optional (group #:op_stx ~! (~or* self-id:identifier
                                              (_::block (group self-id:identifier))))
                     #:defaults ([self-id #'self]))
          (~optional (group #:all_stx ~! (~or* all-id:identifier
                                               (_::block (group all-id:identifier))))
                     #:defaults ([all-id #'#f]))))

  (define-syntax-class-mixin extra-options
    #:datum-literals (group)
    (~alt (group (~var _ (:keyword-matching extra-kws))
                 ~!
                 (~or* (_::block (group _))
                       _))))

  (define-composed-splicing-syntax-class (:prefix-operator-options space-sym)
    operator-options)

  (define-composed-splicing-syntax-class (:self-operator-options space-sym extra-kws)
    self-options
    extra-options)

  (define-composed-splicing-syntax-class (:macro-prefix-operator-options space-sym extra-kws)
    operator-options
    self-options
    extra-options)

  (define-splicing-syntax-class (:macro-maybe-prefix-operator-options space-sym prec? extra-kws)
    #:attributes (prec self-id all-id)
    (pattern (~and (~fail #:when prec?)
                   (~var || (:self-operator-options space-sym extra-kws)))
             #:with prec #'())
    (pattern (~and (~fail #:unless prec?)
                   (~var || (:macro-prefix-operator-options space-sym extra-kws)))))

  (define-syntax-class-mixin infix-operator-options
    #:datum-literals (group)
    (~alt (~optional (group #:associativity ~!
                            (~or* (_::block (group (~and assc
                                                         (~or* #:right #:left #:none))))
                                  (~and assc (~or* #:right #:left #:none))))
                     #:defaults ([assc #'()]))))

  (define-composed-splicing-syntax-class (:infix-operator-options space-sym)
    operator-options
    infix-operator-options)

  (define-composed-splicing-syntax-class (:macro-infix-operator-options space-sym extra-kws)
    operator-options
    infix-operator-options
    self-options
    extra-options)

  (define-composed-splicing-syntax-class (:postfix-operator-options space-sym)
    operator-options)

  (define-composed-splicing-syntax-class (:all-operator-options space-sym)
    operator-options
    infix-operator-options)

  (define-composed-splicing-syntax-class (:macro-all-operator-options space-sym extra-kws)
    operator-options
    infix-operator-options
    extra-options)

  (define-composed-splicing-syntax-class (:transformer-options space-sym extra-kws)
    self-options
    extra-options)

  (define-composed-splicing-syntax-class (:sequence-transformer-options space-sym)
    self-options)

  (define-syntax-class :$+1
    #:attributes (name)
    #:description "unquote operator"
    #:opaque
    (pattern ::name
             #:when (free-identifier=? (in-binding-space #'name) (bind-quote $)
                                       (add1 (syntax-local-phase-level)) (syntax-local-phase-level))))

  (define-splicing-syntax-class :operator-or-identifier-or-$
    #:attributes (name extends)
    #:description "operator-macro pattern"
    #:datum-literals (op group)
    (pattern (~seq ::name)
             #:when (not (free-identifier=? (in-binding-space #'name) (bind-quote $)
                                            (add1 (syntax-local-phase-level)) (syntax-local-phase-level)))
             #:with extends #'#f)
    (pattern (~seq (_::parens (group seq::dotted-operator-or-identifier-sequence)))
             #:with ::dotted-operator-or-identifier #'seq)
    (pattern (~seq _::$+1 (_::parens (group (_::quotes (group (op (~and name (~datum $))))))))
             #:with extends #'#f))

  (define-syntax-class :identifier-for-parsed
    #:attributes (id)
    #:description "identifier for a parsed sequence"
    #:datum-literals (group)
    (pattern id:identifier)
    (pattern (tag::parens
              ~!
              (~fail #:unless (free-identifier=? (in-unquote-binding-space (datum->syntax #'tag '#%parens))
                                                 (unquote-bind-quote #%parens)
                                                 (add1 (syntax-local-phase-level)) (syntax-local-phase-level)))
              (group ::identifier-for-parsed))))

  (define-splicing-syntax-class :operator-syntax-quote
    #:description "operator-macro pattern"
    #:datum-literals (op group)
    (pattern (_::quotes (~and g (group _::$+1 _::identifier-for-parsed _::operator-or-identifier-or-$ . _))))
    (pattern (_::quotes (~and g (group _::operator-or-identifier-or-$ . _)))))

  (define (convert-prec prec)
    #`(lambda () (list #,@(for/list ([p (in-list (syntax->list prec))])
                            (syntax-parse p
                              [(#:other . spec) #`'(default . spec)]
                              [(op . spec) #`(cons (quote-syntax op) 'spec)])))))

  (define (convert-assc assc)
    (if (null? (syntax-e assc))
        #''left
        #`'#,(string->symbol (keyword->immutable-string (syntax-e assc)))))

  (define (check-parsed-right-form form-id tail-pattern)
    (syntax-parse tail-pattern
      #:datum-literals (op group)
      [((~and op-stx _::$+1) right::identifier-for-parsed) #'right.id]
      [_ #f])))

;; parse one case (possibly the only case) in a macro definition
(define-for-syntax (parse-one-macro-definition form-id kind allowed space-sym
                                               [main-prec #'()] [main-assc #'()] [main-kws '()]
                                               [extra-kws '()] [extra-shapes '()])
  (lambda (g rhs)
    (define (combine-main prec main-prec what)
      (cond
        [(null? (syntax-e main-prec)) prec]
        [(null? (syntax-e prec)) main-prec]
        [else (raise-syntax-error #f
                                  (format "cannot specify ~a in individual case" what)
                                  rhs)]))
    (syntax-parse g
      #:datum-literals (group op)
      ;; infix protocol
      [(group _::$+1 left::identifier-for-parsed
              op-name::operator-or-identifier-or-$
              . tail-pattern)
       (unless (memq 'infix allowed)
         (raise-syntax-error (syntax-e form-id)
                             "infix pattern is not allowed"
                             g))
       (define parsed-right-id (check-parsed-right-form form-id #'tail-pattern))
       (syntax-parse rhs
         [(tag::block (~var opt (:macro-infix-operator-options space-sym extra-kws)) rhs ...)
          #`(pre-parsed op-name.name
                        op-name.extends
                        infix
                        #,kind
                        opt
                        #,(extract-extra-binds g extra-kws extra-shapes #'opt main-kws)
                        #,(convert-prec (combine-main #'opt.prec main-prec "precedence"))
                        #,(convert-assc (combine-main #'opt.assc main-assc "associativity"))
                        #,parsed-right-id
                        [tail-pattern
                         opt.self-id
                         opt.all-id
                         left.id
                         (tag rhs ...)])])]
      ;; prefix protocol
      [(group op-name::operator-or-identifier-or-$
              . tail-pattern)
       (unless (memq 'prefix allowed)
         (raise-syntax-error (syntax-e form-id)
                             "prefix pattern is not allowed"
                             g))
       (define parsed-right-id (check-parsed-right-form form-id #'tail-pattern))
       (syntax-parse rhs
         [(tag::block (~var opt (:macro-maybe-prefix-operator-options space-sym (memq 'precedence allowed) extra-kws))
                      rhs ...)
          #`(pre-parsed op-name.name
                        op-name.extends
                        prefix
                        #,kind
                        opt
                        #,(extract-extra-binds g extra-kws extra-shapes #'opt #f)
                        #,(convert-prec (combine-main #'opt.prec main-prec "precedence"))
                        #,main-assc
                        #,parsed-right-id
                        [tail-pattern
                         opt.self-id
                         opt.all-id
                         (tag rhs ...)])])])))

(define-for-syntax (pre-parsed-name pre-parsed)
  (syntax-parse pre-parsed
    [(_ name . _) #'name]))

(define-for-syntax (pre-parsed-extends pre-parsed)
  (syntax-parse pre-parsed
    [(_ _ extends . _) #'extends]))

;; single-case macro definition:
(define-for-syntax (parse-operator-definition form-id kind stx g rhs space-sym compiletime-id
                                              #:allowed [allowed '(prefix infix precedence)]
                                              #:extra-kws [extra-kws '()]
                                              #:extra-shapes [extra-shapes '()])
  (define p ((parse-one-macro-definition form-id kind allowed space-sym
                                         #'() #'() null
                                         extra-kws extra-shapes)
             g rhs))
  (define op (pre-parsed-name p))
  (if compiletime-id
      (build-syntax-definition/maybe-extension space-sym op
                                               (pre-parsed-extends p)
                                               #`(#,compiletime-id #:single #,stx #,p))
      p))

;; multi-case macro definition:
(define-for-syntax (parse-operator-definitions form-id kind stx gs rhss space-sym compiletime-id
                                               main-name main-extends main-prec main-assc main-kws
                                               #:allowed [allowed '(prefix infix precedence)]
                                               #:extra-kws [extra-kws '()]
                                               #:extra-shapes [extra-shapes '()])
  (define ps (map (parse-one-macro-definition form-id kind allowed space-sym
                                              main-prec main-assc main-kws
                                              extra-kws extra-shapes)
                  gs rhss))
  (check-consistent stx
                    (let ([names (map pre-parsed-name ps)])
                      (if main-name (cons main-name names) names))
                    #:has-main? main-name
                    "operator")
  (if compiletime-id
      (build-syntax-definition/maybe-extension space-sym (or main-name (pre-parsed-name (car ps)))
                                               (or main-extends (pre-parsed-extends (car ps)))
                                               #`(#,compiletime-id #:multi #,stx #,@ps))
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
     #'(define-operator-definition-transformer
         id
         'protocol
         space
         #:extra ()
         #'make-prefix-id
         #'make-infix-id
         #'prefix+infix-id)]
    [(_ id
        'protocol
        space
        #:extra ([extra-kw extra-get-static-infos extra-shape] ...)
        #'make-prefix-id
        #'make-infix-id
        #'prefix+infix-id)
     #`(begin
         (define-defn-syntax id
           (make-operator-definition-transformer-runtime 'protocol
                                                         'space
                                                         #'compiletime-id
                                                         '(extra-kw ...)
                                                         '(extra-shape ...)))
         (begin-for-syntax
           (define-syntax compiletime-id
             (make-operator-definition-transformer-compiletime #'make-prefix-id
                                                               #'make-infix-id
                                                               #'prefix+infix-id
                                                               'space
                                                               #'(extra-get-static-infos ...)
                                                               '(extra-shape ...)))))]))

(define-for-syntax (make-operator-definition-transformer-runtime protocol
                                                                 space-sym
                                                                 compiletime-id
                                                                 extra-kws
                                                                 extra-shapes)
  (define kind protocol)
  (definition-transformer
    (lambda (stx)
      (syntax-parse (replace-head-dotted-name stx)
        #:datum-literals (group)
        [(form-id (alts-tag::alts (_::block (group q::operator-syntax-quote
                                                   (~and rhs (_::block body ...))))
                                  ...+))
         (list (parse-operator-definitions #'form-id
                                           kind
                                           stx
                                           (syntax->list #'(q.g ...))
                                           (syntax->list #'(rhs ...))
                                           space-sym
                                           compiletime-id
                                           #f #f
                                           #'() #'() '()
                                           #:extra-kws extra-kws
                                           #:extra-shapes extra-shapes))]
        [(form-id main-op::operator-or-identifier-or-$
                  (~optional
                   (_::block
                    (~var main-options (:macro-all-operator-options space-sym extra-kws))))
                  (alts-tag::alts ~!
                                  (_::block (group q::operator-syntax-quote
                                                   (~and rhs (_::block body ...))))
                                  ...+))
         (list (parse-operator-definitions #'form-id
                                           kind
                                           stx
                                           (syntax->list #'(q.g ...))
                                           (syntax->list #'(rhs ...))
                                           space-sym
                                           compiletime-id
                                           #'main-op.name #'main-op.extends
                                           (if (attribute main-options) #'main-options.prec #'())
                                           (if (attribute main-options) #'main-options.assc #'())
                                           (if (attribute main-options)
                                               (extract-extra-binds stx extra-kws extra-shapes #'main-options #f)
                                               #'())
                                           #:extra-kws extra-kws
                                           #:extra-shapes extra-shapes))]
        [(form-id q::operator-syntax-quote
                  (~and rhs (_::block body ...)))
         (list (parse-operator-definition #'form-id
                                          kind
                                          stx
                                          #'q.g
                                          #'rhs
                                          space-sym
                                          compiletime-id
                                          #:extra-kws extra-kws
                                          #:extra-shapes extra-shapes))]))))

(begin-for-syntax
  (define-for-syntax (make-operator-definition-transformer-compiletime make-prefix-id
                                                                       make-infix-id
                                                                       prefix+infix-id
                                                                       space-sym
                                                                       extra-get-static-infoss-stx
                                                                       extra-shapes)
    (lambda (stx)
      (syntax-parse stx
        #:datum-literals (group)
        [(form-id #:single orig-stx pre-parsed)
         (parse-operator-definition-rhs #'orig-stx #'pre-parsed
                                        space-sym
                                        make-prefix-id
                                        make-infix-id
                                        #:extra-get-static-infoss extra-get-static-infoss-stx
                                        #:extra-shapes extra-shapes)]
        [(form-id #:multi orig-stx pre-parsed ...)
         (parse-operator-definitions-rhs #'orig-stx (syntax->list #'(pre-parsed ...))
                                         space-sym
                                         make-prefix-id
                                         make-infix-id
                                         prefix+infix-id
                                         #:extra-get-static-infoss extra-get-static-infoss-stx
                                         #:extra-shapes extra-shapes)]))))

;; ----------------------------------------

(begin-for-syntax
  (define-syntax-class :identifier-syntax-quote
    (pattern (_::quotes g::identifier-definition-group)))

  (define-syntax-class :identifier-definition-group
    #:datum-literals (group)
    (pattern (group _::operator-or-identifier-or-$ . _)))

  (define-splicing-syntax-class :identifier-sequence-syntax-quote
    #:datum-literals (group)
    (pattern (_::quotes g::identifier-definition-group
                        . gs))))

(define-for-syntax (parse-transformer-definition g rhs)
  (syntax-parse g
    #:datum-literals (group)
    [(group id::operator-or-identifier-or-$ . tail-pattern)
     #`(pre-parsed id.name
                   id.extends
                   tail-pattern
                   #,rhs)]))

(define-syntax (define-identifier-syntax-definition-transformer stx)
  (syntax-parse stx
    #:literals (syntax)
    [(_ id #:multi (space ...)
        #:extra ([extra-kw extra-get-static-infos extra-shape] ...)
        #'make-transformer-id)
     #`(begin
         (define-defn-syntax id
           (make-identifier-syntax-definition-transformer-runtime '(space ...)
                                                                  #'compiletime-id
                                                                  '(extra-kw ...)
                                                                  '(extra-shape ...)))
         (begin-for-syntax
           (define-syntax compiletime-id
             (make-identifier-syntax-definition-transformer-compiletime
              #'make-transformer-id #'(extra-get-static-infos ...) '(extra-shape ...)))))]
    [(_ id #:multi m
        #'make-transformer-id)
     #'(define-identifier-syntax-definition-transformer id #:multi m
         #:extra ()
         #'make-transformer-id)]
    [(_ id space
        #:extra extra
        #'make-transformer-id)
     #'(define-identifier-syntax-definition-transformer id #:multi (space) #:extra extra #'make-transformer-id)]
    [(_ id space
        #'make-transformer-id)
     #'(define-identifier-syntax-definition-transformer id #:multi (space) #:extra () #'make-transformer-id)]))

(define-for-syntax (make-identifier-syntax-definition-transformer-runtime space-syms
                                                                          compiletime-id
                                                                          extra-kws
                                                                          extra-shapes)
  (definition-transformer
    (lambda (stx)
      (parse-identifier-syntax-transformer
       stx
       compiletime-id extra-kws extra-shapes
       (lambda (p ct)
         (define name (pre-parsed-name p))
         (build-syntax-definitions/maybe-extension
          space-syms name (pre-parsed-extends p)
          #`(let ([#,name #,ct])
              (values #,@(for/list ([space-sym (in-list space-syms)])
                           name)))))
       (lambda (ps ct)
         (define name (pre-parsed-name (car ps)))
         (build-syntax-definitions/maybe-extension
          space-syms name (pre-parsed-extends (car ps))
          #`(let ([#,name #,ct])
              (values #,@(for/list ([space-sym (in-list space-syms)])
                           name)))))))))

(define-for-syntax (parse-identifier-syntax-transformer stx compiletime-id extra-kws extra-shapes k ks)
  (syntax-parse stx
    #:datum-literals (group)
    [(form-id q::identifier-syntax-quote
              (~and rhs (tag::block
                         (~var opt (:transformer-options #f extra-kws))
                         body ...)))
     (define p (parse-transformer-definition #'q.g #'(tag body ...)))
     (k p #`(#,compiletime-id (#,p) (opt.self-id) (opt.all-id) (#,(extract-extra-binds stx extra-kws extra-shapes #'opt #f))))]
    [(form-id (_::alts
               (_::block
                (group
                 q::identifier-syntax-quote
                 (~and rhs (tag::block
                            (~var opt (:transformer-options #f extra-kws))
                            body ...))))
               ...))
         (define ps (for/list ([g (in-list (syntax->list #'(q.g ...)))]
                               [b (in-list (syntax->list #'((tag body ...) ...)))])
                      (parse-transformer-definition g b)))
         (check-consistent stx
                           (map pre-parsed-name ps)
                           "operator")
         (ks ps #`(#,compiletime-id #,ps (opt.self-id ...) (opt.all-id ...) #,(map (lambda (opts)
                                                                                     (extract-extra-binds stx extra-kws extra-shapes opts #f))
                                                                                   (syntax->list #'(opt ...)))))]))

(begin-for-syntax
  (define (extract-extra-binds stx extra-kws extra-shapes opts main-kws)
    (define-values (kws-stx binds-stx)
      (for/lists (kws-stx binds-stx) ([opt (in-list (syntax->list opts))]
                                      #:do [(define-values (kw bind)
                                              (syntax-parse opt
                                                #:datum-literals (group)
                                                [(group (~var kw (:keyword-matching extra-kws))
                                                        ~!
                                                        (~or* (_::block (group bind))
                                                              bind))
                                                 (values #'kw #'bind)]
                                                [_ (values #f #f)]))]
                                      #:when kw)
        (values kw bind)))
    (define shape-ht (for/hasheq ([extra-kw (in-list extra-kws)]
                                  [extra-shape (in-list extra-shapes)])
                       (values extra-kw extra-shape)))
    (define main-ht (if main-kws
                        (for/hasheq ([extra-kw (in-list extra-kws)]
                                     [main-kw (in-list main-kws)])
                          (values extra-kw main-kw))
                        #hasheq()))
    (define ht (for/fold ([ht main-ht]) ([kw-stx (in-list kws-stx)]
                                         [bind (in-list binds-stx)])
                 (when (hash-ref ht (syntax-e kw-stx) #f)
                   (raise-syntax-error #f "duplicate option" stx kw-stx))
                 (case (hash-ref shape-ht (syntax-e kw-stx))
                   [(pattern)
                    (syntax-parse bind
                      [(_::quotes _) (void)]
                      [_ (raise-syntax-error #f "expected a group syntax pattern" stx bind)])]
                   [else
                    (unless (identifier? bind)
                      (raise-syntax-error #f "expected an identifier" stx bind))])
                 (hash-set ht (syntax-e kw-stx) bind)))
    (for/list ([kw (in-list extra-kws)])
      (hash-ref ht kw #f))))

(begin-for-syntax
  (define-for-syntax (make-identifier-syntax-definition-transformer-compiletime
                      make-transformer-id extra-get-static-infoss-stx extra-shapes)
    (lambda (stx)
      (syntax-parse stx
        [(_ pre-parseds self-ids all-ids extra-argument-binds)
         (parse-transformer-definition-rhs (syntax->list #'pre-parseds)
                                           (syntax->list #'self-ids)
                                           (syntax->list #'all-ids)
                                           (syntax->list #'extra-argument-binds)
                                           make-transformer-id
                                           extra-get-static-infoss-stx
                                           extra-shapes)]))))

(define-syntax (define-identifier-syntax-definition-sequence-transformer stx)
  (syntax-parse stx
    #:literals (syntax)
    [(_ id space
        #'make-transformer-id)
     #`(begin
         (define-defn-syntax id
           (make-identifier-syntax-definition-sequence-transformer-runtime 'space
                                                                           #'compiletime-id))
         (begin-for-syntax
           (define-syntax compiletime-id
             (make-identifier-syntax-definition-sequence-transformer-compiletime #'make-transformer-id))))]))

(define-for-syntax (make-identifier-syntax-definition-sequence-transformer-runtime space-sym
                                                                                   compiletime-id)
  (definition-transformer
    (lambda (stx)
     (syntax-parse stx
       #:datum-literals (group)
       [(form-id q::identifier-sequence-syntax-quote
                 (~and rhs (tag::block
                            (~var opt (:sequence-transformer-options space-sym))
                            body ...)))
        (define p (parse-transformer-definition #'q.g #'(tag body ...)))
        (define name (pre-parsed-name p))
        (build-syntax-definitions/maybe-extension
         (list space-sym) name (pre-parsed-extends p)
         #`(let ([#,name (#,compiletime-id #,p q.gs opt.self-id opt.all-id)])
             #,name))]))))

(begin-for-syntax
  (define-for-syntax (make-identifier-syntax-definition-sequence-transformer-compiletime make-transformer-id)
    (lambda (stx)
      (syntax-parse stx
        [(_ pre-parsed gs self-id all-id)
         (parse-transformer-definition-sequence-rhs #'pre-parsed #'self-id #'all-id
                                                    make-transformer-id
                                                    #'gs)]))))
