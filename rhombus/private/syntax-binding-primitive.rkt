#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest/hier-name-parse
                     "name-path-op.rkt")
         syntax/parse/pre
         "pack.rkt"
         "syntax-class.rkt"
         (submod "syntax-class.rkt" for-quasiquote)
         (only-in "annotation.rkt"
                  ::)
         "pattern-variable.rkt"
         "syntax-binding.rkt"
         "name-root-ref.rkt"
         "parens.rkt"
         (submod "function.rkt" for-call))

(provide (for-space rhombus/syntax_binding
                    _
                    #%parens
                    ::
                    &&
                    \|\|
                    #%literal
                    #%block))

(module+ for-quasiquote
  (provide (for-syntax identifier-as-pattern-syntax)))

;; `#%quotes` is impemented in 'quasiquote.rkt", because it recurs as
;; nested quasiquote matching

(define-for-syntax (identifier-as-pattern-syntax id kind
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
            (list #`[#,id (make-pattern-variable-syntax (quote-syntax #,id)
                                                        (quote-syntax #,temp2)
                                                        (quote-syntax #,unpack*)
                                                        0
                                                        #f
                                                        #'())])
            (list (pattern-variable (syntax-e id) temp2 0 unpack*)))))

(define-syntax-binding-syntax _
  (syntax-binding-prefix-operator
   #'_
   null
   'macro
   (lambda (stx)
     (syntax-parse stx
       [(form-id . tail)
        (values #`(#,(syntax/loc #'form-id _) () () ())
                #'tail)]))))

(define-syntax-binding-syntax #%parens
  (syntax-binding-prefix-operator
   #'#%parens
   null
   'macro
   (lambda (stx)
     (syntax-parse stx
       [(_ (parens g::syntax-binding) . tail)
        (values #'g.parsed
                #'tail)]))))

(begin-for-syntax
  (define-splicing-syntax-class :syntax-class-args
    (pattern (~seq (~and args (_::parens . _))))
    (pattern (~seq)
             #:attr args #'#f))
  (define (parse-syntax-class-args stx-class rator-in arity class-args)
    (cond
      [(not arity)
       (when (syntax-e class-args)
         (raise-syntax-error #f
                             "syntax class does not expect arguments"
                             stx-class))
       rator-in]
      [(not (syntax-e class-args))
       (raise-syntax-error #f
                           "syntax class expects arguments"
                           stx-class)]
      [else
       (define-values (call empty-tail)
         (parse-function-call rator-in '() #`(#,stx-class #,class-args)
                              #:static? #t
                              #:rator-stx stx-class
                              #:rator-kind '|syntax class|
                              #:rator-arity arity))
       call])))

(define-syntax-binding-syntax ::
  (syntax-binding-infix-operator
   #'::
   null
   'macro
   (lambda (form1 stx)
     (unless (or (identifier? form1)
                 (syntax-parse form1
                   [(underscore () () ())
                    (free-identifier=? #'underscore #'_)]))
       (raise-syntax-error #f
                           "preceding term must be an identifier or `_`"
                           (syntax-parse stx
                             [(colons . _) #'colons])))
     (define (build stx-class class-args open-attributes)
       (with-syntax ([id (if (identifier? form1) form1 #'wildcard)])
         (define rsc (syntax-local-value (in-syntax-class-space stx-class) (lambda () #f)))
         (define (compat pack* unpack*)
           (define sc (rhombus-syntax-class-class rsc))
           (define sc-call (parse-syntax-class-args stx-class
                                                    sc
                                                    (rhombus-syntax-class-arity rsc)
                                                    class-args))
           (define temp0-id (car (generate-temporaries (list #'id))))
           (define temp-id (car (generate-temporaries (list #'id))))
           (define vars (for/list ([l (in-list (syntax->list (rhombus-syntax-class-attributes rsc)))])
                          (syntax-list->pattern-variable l)))
           (define-values (attribute-bindings attribute-vars)
             (for/lists (bindings descs) ([var (in-list vars)]
                                          [temp-attr (in-list (generate-temporaries (map pattern-variable-sym vars)))])
               (define name (pattern-variable-sym var))
               (define depth (pattern-variable-depth var))
               (define unpack*-id (pattern-variable-unpack*-id var))
               (define id-with-attr
                 (datum->syntax temp0-id (string->symbol (format "~a.~a" (syntax-e temp0-id) name))))
               (values #`[#,temp-attr #,(cond
                                          [(eq? depth 'tail)
                                           ;; bridge from a primitive syntax class, where we don't want to convert to
                                           ;; a list and then convert back when the tail is used as a new tail in a
                                           ;; template
                                           #`(pack-tail* (syntax #,id-with-attr) 0)]
                                          [(not (or (free-identifier=? unpack*-id #'unpack-tail-list*)
                                                    (free-identifier=? unpack*-id #'unpack-multi-tail-list*)))
                                           ;; assume depth-compatible value checked on binding side, and
                                           ;; let `attribute` unpack syntax repetitions
                                           #`(pack-nothing* (attribute #,id-with-attr) #,depth)]
                                          [else
                                           #`(#,(cond
                                                  [(free-identifier=? unpack*-id #'unpack-tail-list*)
                                                   #'pack-tail-list*]
                                                  [(free-identifier=? unpack*-id #'unpack-multi-tail-list*)
                                                   #'pack-multi-tail-list*]
                                                  [else #'pack-term*])
                                              (syntax #,(let loop ([t id-with-attr] [depth depth])
                                                          (if (zero? depth)
                                                              t
                                                              (loop #`(#,t #,(quote-syntax ...)) (sub1 depth)))))
                                              #,depth)])]
                       (pattern-variable name temp-attr (if (eq? depth 'tail) 1 depth) unpack*-id))))
           (define found-attributes
             (and open-attributes
                  (for/hasheq ([var (in-list attribute-vars)])
                    (values (pattern-variable-sym var) var))))
           (when open-attributes
             (for ([(name field+bind) (in-hash open-attributes)])
               (define field (car field+bind))
               (unless (hash-ref found-attributes name #f)
                 (raise-syntax-error #f
                                     "not an attribute of the syntax class"
                                     field))))
           (define pack-depth (if (rhombus-syntax-class-splicing? rsc) 1 0))
           #`(#,(if sc
                    #`(~var #,temp0-id #,sc-call)
                    temp0-id)
              #,(cons #`[#,temp-id (#,pack* (syntax #,temp0-id) #,pack-depth)] attribute-bindings)
              #,(append
                 (if (identifier? form1)
                     (list #`[id (make-pattern-variable-syntax
                                  (quote-syntax id)
                                  (quote-syntax #,temp-id)
                                  (quote-syntax #,unpack*)
                                  #,pack-depth
                                  #,(rhombus-syntax-class-splicing? rsc)
                                  (quote-syntax #,(map pattern-variable->list attribute-vars)))])
                     null)
                 (if (not open-attributes)
                     null
                     (for/list ([name (in-list (hash-keys open-attributes #t))])
                       (define field+bind (hash-ref open-attributes name))
                       (define var (hash-ref found-attributes name))
                       #`[#,(cdr field+bind) (make-pattern-variable-syntax
                                              (quote-syntax #,(cdr field+bind))
                                              (quote-syntax #,(pattern-variable-val-id var))
                                              (quote-syntax #,(pattern-variable-unpack*-id var))
                                              #,(pattern-variable-depth var)
                                              #f
                                              #'())])))
              #,(append
                 (if (identifier? form1)
                     (list (list #'id temp-id pack-depth unpack*))
                     null)
                 (if (not open-attributes)
                     null
                     (for/list ([name (in-list (hash-keys open-attributes #t))])
                       (define field+bind (hash-ref open-attributes name))
                       (define var (hash-ref found-attributes name))
                       (cons (cdr field+bind) (cdr (pattern-variable->list var))))))))
         (define (incompat)
           (raise-syntax-error #f
                               "syntax class incompatible with this context"
                               stx-class))
         (define (retry) #'#f)
         (define kind (current-syntax-binding-kind))
         (cond
           [(not (rhombus-syntax-class? rsc))
            (raise-syntax-error #f
                                "not bound as a syntax class"
                                stx-class)]
           [(eq? (rhombus-syntax-class-kind rsc) 'term)
            (cond
              [(not (eq? kind 'term)) (retry)]
              [else (compat #'pack-term* #'unpack-term*)])]
           [(eq? (rhombus-syntax-class-kind rsc) 'group)
            (cond
              [(eq? kind 'term) (incompat)]
              [(not (eq? kind 'group)) (retry)]
              [else (compat #'pack-group* #'unpack-group*)])]
           [(eq? (rhombus-syntax-class-kind rsc) 'multi)
            (cond
              [(or (eq? kind 'multi) (eq? kind 'block))
               (compat #'pack-tagged-multi* #'unpack-multi-as-term*)]
              [else (incompat)])]
           [(eq? (rhombus-syntax-class-kind rsc) 'block)
            (cond
              [(eq? kind 'block)
               (compat #'pack-block* #'unpack-multi-as-term*)]
              [else (incompat)])]
           [else
            (error "unrecognized kind" kind)])))
     (syntax-parse stx
       [(_ . rest)
        #:with (~var stx-class-hier (:hier-name-seq in-syntax-class-space name-path-op name-root-ref)) #'rest
        #:with tail #'stx-class-hier.tail
        (syntax-parse #'tail
          #:datum-literals (group)
          [(args::syntax-class-args (_::block (group field:identifier #:as bind:identifier) ...))
           (values (build #'stx-class-hier.name
                          #'args.args
                          (for/hasheq ([field (in-list (syntax->list #'(field ...)))]
                                       [bind (in-list (syntax->list #'(bind ...)))])
                            (values (syntax-e field) (cons field bind))))
                   #'())]
          [(args::syntax-class-args (_::block . _))
           (raise-syntax-error #f "expected `attribute ~as identifier` sequence in block" stx)]
          [(args::syntax-class-args . tail)
           (values (build #'stx-class-hier.name #'args.args #f) #'tail)])]))
   'none))

(define-for-syntax (normalize-id form)
  (if (identifier? form)
      (identifier-as-pattern-syntax form (current-syntax-binding-kind))
      form))

(define-for-syntax (norm-seq pat like-pat)
  (syntax-parse pat
    [((~datum ~seq) . _) pat]
    [_ (syntax-parse like-pat
         [((~datum ~seq) . _) #`(~seq #,pat)]
         [_ pat])]))

(define-syntax-binding-syntax &&
  (syntax-binding-infix-operator
   #'&&
   null
   'automatic
   (lambda (form1 form2 stx)
     (syntax-parse (normalize-id form1)
       [#f #'#f]
       [(pat1 (idr1 ...) (sidr1 ...) (var1 ...))
        (syntax-parse (normalize-id form2)
          [#f #'#f]
          [(pat2 idrs2 sidrs2 vars2)
           #`((~and #,(norm-seq #'pat1 #'pat2) #,(norm-seq #'pat2 #'pat1))
              (idr1 ... . idrs2)
              (sidr1 ... . sidrs2)
              (var1 ... . vars2))])]))
   'left))

(define-syntax-binding-syntax \|\|
  (syntax-binding-infix-operator
   #'\|\|
   null
   'automatic
   (lambda (form1 form2 stx)
     (syntax-parse (normalize-id form1)
       [#f #'#f]
       [(pat1 idrs1 sidrs1 vars1)
        (syntax-parse (normalize-id form2)
          [#f #'#f]
          [(pat2 idrs2 sidrs2 vars2)
           #`((~or #,(norm-seq #'pat1 #'pat2)
                   #,(norm-seq #'pat2 #'pat1))
              ()
              ()
              ())])]))
   'left))

(define-syntax-binding-syntax #%literal
  (syntax-binding-prefix-operator
   #'#%literal
   '((default . stronger))
   'macro
   (lambda (stxes)
     (syntax-parse stxes
       [(_ x . _)
        (raise-syntax-error #f
                            (format "misplaced ~a within a syntax binding"
                                    (if (keyword? (syntax-e #'x))
                                        "keyword"
                                        "literal"))
                            #'x)]))))

(define-syntax-binding-syntax #%block
  (syntax-binding-prefix-operator
   #'#%body
   '((default . stronger))
   'macro
   (lambda (stxes)
     (syntax-parse stxes
       [(_ b)
        (raise-syntax-error #f
                            "not allowed as a syntax binding by itself"
                            #'b)]))))
