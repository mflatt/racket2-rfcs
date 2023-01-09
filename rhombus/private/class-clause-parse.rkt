#lang racket/base
(require (for-syntax racket/base
                     syntax/parse
                     enforest/hier-name-parse
                     "srcloc.rkt"
                     "name-path-op.rkt"
                     "class-parse.rkt"
                     (only-in "rule.rkt" rule)
                     "consistent.rkt")
         "class+interface.rkt"
         "class-clause.rkt"
         "interface-clause.rkt"
         (only-in "annotation.rkt" :: -:)
         (submod "annotation.rkt" for-class)
         "entry-point.rkt"
         "parens.rkt"
         "name-root.rkt"
         "name-root-ref.rkt"
         "parse.rkt"
         "var-decl.rkt"
         (only-in "assign.rkt" :=)
         (only-in "function.rkt" fun)
         (only-in "implicit.rkt" #%body)
         (only-in "begin.rkt"
                  [begin rhombus-begin]))

(provide (for-syntax extract-internal-ids
                     make-expose
                     parse-annotation-options
                     parse-options
                     wrap-class-clause
                     class-clause-accum
                     class-clause-extract
                     method-shape-extract)
         rhombus-class
         extends
         implements
         internal
         constructor
         expression
         binding
         annotation
         final
         nonfinal
         authentic
         field
         method
         property
         override
         private
         abstract)

(module+ for-interface
  (provide (for-syntax parse-method-clause
                       extract-rhs)))

(define-for-syntax (extract-internal-ids options
                                         scope-stx base-stx
                                         stxes)
  (define internal-ids (reverse (hash-ref options 'internals '())))
  (define internal-id (and (pair? internal-ids) (car internal-ids)))
  (define extra-internal-ids (if (pair? internal-ids) (cdr internal-ids) '()))
  (define expose (if internal-id
                     (make-expose scope-stx base-stx)
                     (lambda (stx) stx)))
  (values internal-id
          (expose internal-id)
          (map expose extra-internal-ids)))

(define-for-syntax (make-expose scope-stx base-stx)
  (let ([intro (make-syntax-delta-introducer scope-stx base-stx)])
    (lambda (stx)
      (intro stx 'remove))))

(define-for-syntax (extract-rhs b)
  (syntax-parse b
    [(_::block g) #'g]
    [else
     (raise-syntax-error #f
                         "expected a single entry point in block body"
                         b)]))

(define-for-syntax (parse-annotation-options orig-stx forms)
  (syntax-parse forms
    #:context orig-stx
    [((_ clause-parsed) ...)
     (let loop ([clauses (syntax->list #'(clause-parsed ...))] [options #hasheq()])
       (cond
         [(null? clauses) options]
         [else
          (define clause (car clauses))
          (define new-options
            (syntax-parse clause
              #:literals (extends implements private-implements
                                  constructor final nonfinal authentic binding annotation
                                  method property private override abstract internal
                                  final-override private-override
                                  override-property final-property final-override-property
                                  private-property private-override-property
                                  abstract-property)
              [(extends id)
               (when (hash-has-key? options 'extends)
                 (raise-syntax-error #f "multiple extension clauses" orig-stx clause))
               (hash-set options 'extends #'id)]
              [(internal id)
               (hash-set options 'internals (cons #'id (hash-ref options 'internals '())))]
              [(annotation block)
               (when (hash-has-key? options 'annotation-rhs)
                 (raise-syntax-error #f "multiple annotation clauses" orig-stx clause))
               (hash-set options 'annotation-rhs (extract-rhs #'block))]
              [_ options]))
          (loop (cdr clauses) new-options)]))]))

(define-for-syntax (parse-options orig-stx forms)
  (syntax-parse forms
    #:context orig-stx
    [((_ clause-parsed) ...)
     (define clauses (syntax->list #'(clause-parsed ...)))
     (define (add-implements options extra-key ids-stx)
       (define l (reverse (syntax->list ids-stx)))
       (define new-options
         (hash-set options 'implements (append l (hash-ref options 'implements '()))))
       (if extra-key
           (hash-set new-options extra-key (append l (hash-ref new-options extra-key '())))
           new-options))
     (let loop ([clauses clauses] [options #hasheq()])
       (cond
         [(null? clauses) options]
         [else
          (define clause (car clauses))
          (define new-options
            (syntax-parse clause
              #:literals (extends implements private-implements
                                  constructor expression final nonfinal authentic binding annotation
                                  method property private override abstract internal
                                  final-override private-override
                                  override-property final-property final-override-property
                                  private-property private-override-property
                                  abstract-property)
              [(extends id) ; checked in `parse-annotation-options`
               (hash-set options 'extends #'id)]
              [(implements id ...)
               (add-implements options 'public-implements #'(id ...))]
              [(private-implements id ...)
               (add-implements options 'private-implements #'(id ...))]
              [(internal id)
               (hash-set options 'internals (cons #'id (hash-ref options 'internals '())))]
              [(constructor id rhs)
               (when (hash-has-key? options 'constructor-rhs)
                 (raise-syntax-error #f "multiple constructor clauses" orig-stx clause))
               (define rhs-options (hash-set options 'constructor-rhs #'rhs))
               (if (syntax-e #'id)
                   (hash-set rhs-options 'constructor-name #'id)
                   rhs-options)]
              [(expression rhs)
               (when (hash-has-key? options 'expression-rhs)
                 (raise-syntax-error #f "multiple expression macro clauses" orig-stx clause))
               (hash-set options 'expression-rhs (extract-rhs #'rhs))]
              [(binding block)
               (when (hash-has-key? options 'binding-rhs)
                 (raise-syntax-error #f "multiple binding clauses" orig-stx clause))
               (hash-set options 'binding-rhs (extract-rhs #'block))]
              [(annotation block) ; checked in `parse-annotation-options`
               (hash-set options 'annotation-rhs (extract-rhs #'block))]
              [(nonfinal)
               (when (hash-has-key? options 'final?)
                 (raise-syntax-error #f "multiple finality clauses" orig-stx clause))
               (hash-set options 'final? #f)]
              [(authentic)
               (when (hash-has-key? options 'authentic?)
                 (raise-syntax-error #f "multiple authenticity clause" orig-stx clause))
               (hash-set options 'authentic? #t)]
              [(field id rhs-id ann-seq blk form-id mode)
               (with-syntax ([(predicate annotation-str static-infos)
                              (syntax-parse #'ann-seq
                                [#f (list #'#f #'#f #'())]
                                [(c::inline-annotation)
                                 (list #'c.predicate #'c.annotation-str #'c.static-infos)])])
                 (hash-set options 'fields (cons (added-field #'id
                                                              #'rhs-id #'blk #'form-id
                                                              #'static-infos
                                                              #'predicate
                                                              #'annotation-str
                                                              (syntax-e #'mode))
                                                 (hash-ref options 'fields null))))]
              [_
               (parse-method-clause orig-stx options clause)]))
          (loop (cdr clauses) new-options)]))]))

(define-for-syntax (parse-method-clause orig-stx options clause)
  (syntax-parse clause
    #:literals (extends implements private-implements
                        constructor final nonfinal authentic binding annotation
                        method property private override abstract internal
                        final-override private-override
                        override-property final-property final-override-property
                        private-property private-override-property
                        abstract-property
                        abstract-override abstract-override-property)
    [((~and tag (~or method override private final final-override private-override
                     property override-property
                     final-property final-override-property
                     private-property private-override-property))
      id rhs maybe-ret)
     #:with (_ e-arity::entry-point-arity) #'rhs
     (define-values (body replace disposition kind)
       (case (syntax-e #'tag)
         [(method) (values 'method 'method 'abstract 'method)]
         [(override) (values 'method 'override 'abstract 'method)]
         [(private) (values 'method 'method 'private 'method)]
         [(private-override) (values 'method 'override 'private 'method)]
         [(final) (values 'method 'method 'final 'method)]
         [(final-override) (values 'method 'override 'final 'method)]
         [(property) (values 'method 'method 'abstract 'property)]
         [(override-property) (values 'method 'override 'abstract 'property)]
         [(final-property) (values 'method 'method 'final 'property)]
         [(final-override-property) (values 'method 'override 'final 'property)]
         [(private-property) (values 'method 'method 'private 'property)]
         [(private-override-property) (values 'method 'override 'private 'property)]
         [else (error "method kind not handled" #'tag)]))
     (hash-set options 'methods (cons (added-method #'id
                                                    (car (generate-temporaries #'(id)))
                                                    #'rhs
                                                    #'maybe-ret
                                                    (and (or (pair? (syntax-e #'maybe-ret))
                                                             (syntax-e #'e-arity.parsed))
                                                         (car (generate-temporaries #'(id))))
                                                    body
                                                    replace
                                                    disposition
                                                    kind
                                                    (and (syntax-e #'e-arity.parsed)
                                                         (shift-arity #'e-arity.parsed)))
                                      (hash-ref options 'methods null)))]
    [((~and tag (~or abstract abstract-property abstract-override abstract-override-property))
      id rhs maybe-ret)
     (define-values (replace kind)
       (case (syntax-e #'tag)
         [(abstract) (values 'method 'method)]
         [(abstract-property) (values 'method 'property)]
         [(abstract-override) (values 'override 'method)]
         [(abstract-override-property) (values 'override 'property)]
         [else (error "method kind not handled" #'tag)]))
     (hash-set options 'methods (cons (added-method #'id
                                                    '#:abstract
                                                    #'rhs
                                                    #'maybe-ret
                                                    (and (or (pair? (syntax-e #'maybe-ret))
                                                             #f)
                                                         (car (generate-temporaries #'(id))))
                                                    'abstract
                                                    replace
                                                    'abstract
                                                    kind
                                                    #f)
                                      (hash-ref options 'methods null)))]
    [_
     (raise-syntax-error #f "unrecognized clause" orig-stx clause)]))

(define-for-syntax (shift-arity arity)
  (define a (syntax->datum arity))
  (if (exact-integer? a)
      (* 2 a)
      (cons (* 2 (car a)) (cdr a))))

(define-for-syntax (class-clause-accum forms)
  ;; early processing of a clause to accumulate information of `class-data`;
  ;; keep only things that are useful to report to clause macros
  (for/list ([form (in-list (syntax->list forms))]
             #:do [(define v
                     (syntax-parse form
                       [(_ (_ e) _)
                        (define form #'e)
                        (syntax-parse form
                          #:literals (extends)
                          [(extends id) form]
                          [(implements id ...) form]
                          [_ #f])]))]
             #:when v)
    v))

(define-for-syntax (class-clause-extract who accum key)
  (define (method id vis)
    (case key
      [(method_names) (list id)]
      [(method_visibilities) (list vis)]
      [else null]))
  (define (property id vis)
    (case key
      [(property_names) (list id)]
      [(property_visibilities) (list vis)]
      [else null]))
  (for/list ([a (in-list (reverse (syntax->list accum)))]
             #:do [(define v
                     (syntax-parse a
                       [((~literal extends) id) (if (eq? key 'extends)
                                                    (list #'id)
                                                    null)]
                       [((~literal implements) id ...) (case key
                                                         [(implements)
                                                          (syntax->list #'(id ...))]
                                                         [(implements_visibilities)
                                                          '(public)]
                                                         [else null])]
                       [((~literal private-implements) id ...) (case key
                                                                 [(implements)
                                                                  (syntax->list #'(id ...))]
                                                                 [(implements_visibilities)
                                                                  '(private)]
                                                                 [else null])]
                       [((~literal field) id rhs-id ann-seq blk form-id mode)
                        (case key
                          [(field-names) (list #'id)]
                          [(field-visibilities) (list #'mode)]
                          [else null])]
                       [((~literal internal) id) (case key
                                                   [(internal_names) (list #'id)]
                                                   [else null])]
                       [((~literal method) id . _) (method #'id 'public)]
                       [((~literal override) id . _) (method #'id 'public)]
                       [((~literal private) id . _) (method #'id 'private)]
                       [((~literal private-override) id . _) (method #'id 'private)]
                       [((~literal final) id . _) (method #'id 'public)]
                       [((~literal final-override) id . _) (method #'id 'public)]
                       [((~literal property) id . _) (property #'id 'public)]
                       [((~literal override-property) id . _) (property #'id 'public)]
                       [((~literal final-property) id . _) (property #'id 'public)]
                       [((~literal final-overrode-property) id . _) (property #'id 'public)]
                       [((~literal private-property) id . _) (property #'id 'private)]
                       [((~literal private-override-property) id . _) (property #'id 'private)]
                       [((~literal private-override-property) id . _) (property #'id 'private)]
                       [((~literal constructor) . _) (if (eq? key 'uses_default_constructor) '(#f) null)]
                       [((~literal expression) . _) (if (eq? key 'uses_default_constructor) '(#f) null)]
                       [((~literal binding) . _) (if (eq? key 'uses_default_binding) '(#f) null)]
                       [((~literal annotation) . _) (if (eq? key 'uses_default_annotation) '(#f) null)]
                       [_ null]))]
             [e (in-list v)])
    e))

(define-for-syntax (method-shape-extract shapes private-methods private-properties key)
  (case key
    [(method_names)
     (append
      private-methods
      (for/list ([m (in-vector shapes)]
                 #:unless (pair? m))
        (datum->syntax #f (if (box? m) (unbox m) m))))]
    [(method_visibilities)
     (append
      (for/list ([m (in-list private-methods)])
        'private)
      (for/list ([m (in-vector shapes)]
                 #:unless (pair? m))
        'public))]
    [(property_names)
     (append
      private-properties
      (for ([m (in-vector shapes)]
            #:when (pair? m))
        (let ([m (car m)])
          (datum->syntax #f (if (box? m) (unbox m) m)))))]
    [(property_visibilities)
     (append
      (for/list ([m (in-list private-properties)])
        'private)
      (for/list ([m (in-vector shapes)]
                 #:when (pair? m))
        'public))]))

(define-syntax rhombus-class 'placeholder)

(define-for-syntax (wrap-class-clause parsed)
  #`[(group (parsed (quote-syntax (rhombus-class #,parsed) #:local)))]) ; `quote-syntax` + `rhombus-class` wrapper => clause

(define-for-syntax (parse-multiple-names stx)
  (define lines
    (syntax-parse stx
      [(_ (tag::block (group form ...) ...))
       (syntax->list #'((form ...) ...))]
      [(_ form ...)
       (list #'(form ...))]))
  (apply append
         (for/list ([line (in-list lines)])
           (let loop ([line line])
             (syntax-parse line
               [() null]
               [(~var id (:hier-name-seq in-class-desc-space name-path-op name-root-ref))
                (cons #'id.name (loop #'id.tail))])))))

(define-syntax extends
  (make-class+interface-clause-transformer
   ;; class clause
   (lambda (stx data)
     (syntax-parse stx
       [(_ (~seq form ...))
        #:with (~var id (:hier-name-seq in-class-desc-space name-path-op name-root-ref)) #'(form ...)
        #:with () #'id.tail
        (wrap-class-clause #'(extends id.name))]))
   ;; interface clause
   (lambda (stx data)
     (define names (parse-multiple-names stx))
     (wrap-class-clause #`(extends . #,names)))))

(define-syntax implements
  (class-clause-transformer
   (lambda (stx data)
     (define names (parse-multiple-names stx))
     (wrap-class-clause #`(implements . #,names)))))

(define-syntax internal
  (make-class+interface-clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       [(_ name:identifier)
        (wrap-class-clause #'(internal name))]))))

(define-for-syntax (make-macro-clause-transformer
                    key
                    #:clause-transformer [clause-transformer make-class+interface-clause-transformer])
  (clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       #:datum-literals (group)
       [(form-name (~and (_::quotes . _)
                         pattern)
                   (~and (_::block . _)
                         template-block))
        (wrap-class-clause #`(#,key (block (named-rule rule #,stx pattern template-block))))]
       [(form-name (~and rhs (_::alts
                              (_::block (group (_::quotes . _)
                                               (_::block . _)))
                              ...)))
        (wrap-class-clause #`(#,key (block (named-rule rule #,stx rhs))))]
       [(form-name (~and (_::block . _)
                         a-block))
        (wrap-class-clause #`(#,key a-block))]))))

(define-syntax binding
  (make-macro-clause-transformer #'binding
                                 #:clause-transformer class-clause-transformer))

(define-syntax annotation
  (make-macro-clause-transformer #'annotation))

(define-syntax nonfinal
  (class-clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       [(_) (wrap-class-clause #`(nonfinal))]))))

(define-syntax authentic
  (class-clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       [(_) (wrap-class-clause #`(authentic))]))))

(begin-for-syntax
  (define-splicing-syntax-class (:field mode)
    #:description "field identifier with optional annotation"
    #:attributes (form)
    (pattern (~seq form-id d::var-decl)
             #:with (id:identifier (~optional c::unparsed-inline-annotation)) #'(d.bind ...)
             #:attr ann-seq (if (attribute c)
                                #'c.seq
                                #'#f)
             #:attr form (wrap-class-clause #`(field id
                                                     tmp-id ann-seq d.blk form-id
                                                     #,mode)))))

(define-syntax field
  (class-clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       [((~var f (:field 'public)))
        #'f.form]))))

(define-syntax-rule (if/blocked tst thn els)
  (if tst (let () thn) els))

(begin-for-syntax
  (define-splicing-syntax-class :maybe-ret
    #:attributes (seq)
    #:literals (:: -:)
    #:datum-literals (op)
    (pattern (~seq (~and o (op (~or :: -:))) ret ...)
             #:attr seq #'(o ret ...))
    (pattern (~seq)
             #:attr seq #'()))
  (define-splicing-syntax-class (:method mode)
    #:description "method implementation"
    #:attributes (form)
    #:datum-literals (group)
    (pattern (~seq id:identifier (~and args (_::parens . _)) ret::maybe-ret
                   (~and rhs (_::block . _)))
             #:attr form (wrap-class-clause #`(#,mode id
                                               (block (group fun args rhs))
                                               ret.seq)))
    (pattern (~seq (~and alts
                         (atag::alts
                          (btag::block ((~and gtag group) a-id:identifier
                                                          (~and args (_::parens . _)) ret::maybe-ret
                                                          (~and body (_::block . _))))
                          ...+)))
             #:do [(define a-ids (syntax->list #'(a-id ...)))
                   (check-consistent #:who (syntax-e mode) #'alts a-ids "name")]
             #:attr id (car a-ids)
             #:with (ret0 ...) (let ([retss (syntax->list #'(ret.seq ...))])
                                 (if (for/and ([rets (in-list (cdr retss))])
                                       (same-return-signature? (car retss) rets))
                                     (car retss)
                                     '()))
             #:attr form (wrap-class-clause #`(#,mode id
                                               (block (group fun (atag (btag (gtag args body)) ...)))
                                               (ret0 ...))))
    (pattern (~seq id:identifier ret::maybe-ret (~and rhs (_::block . _)))
             #:attr form (wrap-class-clause #`(#,mode id rhs ret.seq))))
  (define-splicing-syntax-class :method-decl
    #:description "method declaration"
    #:attributes (id rhs maybe-ret)
    (pattern (~seq id:identifier (tag::parens arg ...) ret::maybe-ret)
             #:attr rhs #'(group fun (tag arg ...)
                                 (block (group (parsed (void)))))
             #:attr maybe-ret #'ret.seq)
    (pattern (~seq id:identifier ret::maybe-ret)
             #:attr rhs #'#f
             #:attr maybe-ret #'ret.seq))
  (define-splicing-syntax-class (:property mode)
    #:description "property implementation"
    #:attributes (form)
    #:datum-literals (group op)
    #:literals (:=)
    (pattern (~seq id:identifier ret::maybe-ret
                   (~and rhs (_::block . _)))
             #:attr form (wrap-class-clause #`(#,mode id
                                               (block
                                                (group fun
                                                       (alts
                                                        (block (group (parens) rhs))
                                                        (block (group (parens (group ignored))
                                                                      (block (group (parsed (not-assignable 'id)))))))))
                                               ret.seq)))
    
    (pattern (~seq (_::alts
                    (_::block
                     (group id:identifier ret::maybe-ret
                            (~and rhs (_::block . _))))))
             #:attr form (wrap-class-clause #`(#,mode id
                                               (block
                                                (group fun
                                                       (alts
                                                        (block (group (parens) rhs))
                                                        (block (group (parens (group ignored))
                                                                      (block (group (parsed (not-assignable 'id)))))))))
                                               ret.seq)))
    (pattern (~seq (~and alts
                         (atag::alts
                          (btag1::block
                           ((~and gtag1 group) a-id1:identifier ret1::maybe-ret
                                               (~and body1 (_::block . _))))
                          (btag2::block
                           ((~and gtag2 group) a-id2:identifier
                                               (op :=)
                                               assign-rhs ...+
                                               (~and body2 (_::block . _)))))))
             #:do [(check-consistent #:who (syntax-e mode) #'alts (list #'a-id1 #'a-id2) "name")]
             #:attr form (wrap-class-clause #`(#,mode a-id1
                                               (block (group fun
                                                             (atag
                                                              (btag1 (group (parens) body1))
                                                              (btag2 (group (parens (group assign-rhs ...))
                                                                            body2)))))
                                               ret1.seq))))
  (define-splicing-syntax-class :property-decl
    #:description "proper declaration"
    #:attributes (id rhs maybe-ret)
    (pattern (~seq id:identifier ret::maybe-ret)
             #:attr rhs #'#f
             #:attr maybe-ret #'ret.seq)))

(define-syntax constructor
  (class-clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       #:datum-literals (group)
       [(_ id:identifier (~and args (_::parens . _)) ret ...
           (~and rhs (_::block . _)))
        (wrap-class-clause #`(constructor id (block (group fun args ret ... rhs))))]
       [(_ (~and args (_::parens . _)) ret ...
           (~and rhs (_::block . _)))
        (wrap-class-clause #`(constructor #f (block (group fun args ret ... rhs))))]
       [(_ (~and rhs (_::alts
                      (_::block id:identifier (group (_::parens . _) ret ...
                                                     (_::block . _)))
                      ...+)))
        #:with (id0 idx ...) #'(id ...)
        (for ([idx (in-list (syntax->list #'(idx ...)))])
          (unless (bound-identifier=? idx #'id0)
            (raise-syntax-error #f "inconsistent name identifier" stx idx)))
        (wrap-class-clause #`(constructor id0 (block (group fun rhs))))]
       [(_ (~and rhs (_::alts
                      (_::block (group (_::parens . _) ret ...
                                       (_::block . _)))
                      ...+)))
        (wrap-class-clause #`(constructor #f (block (group fun rhs))))]
       [(_ id:identifier (~and rhs (_::block . _)))
        (wrap-class-clause #`(constructor id rhs))]
       [(_ (~and rhs (_::block . _)))
        (wrap-class-clause #`(constructor #f rhs))]))))

(define-syntax expression
  (make-macro-clause-transformer #'expression))

(define-syntax final
  (make-class+interface-clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       #:literals (override method property)
       [(_ override method (~var m (:method #'final-override))) #'m.form]
       [(_ method (~var m (:method #'final))) #'m.form]
       [(_ override property (~var m (:property #'final-override-property))) #'m.form]
       [(_ property (~var m (:property #'final-property))) #'m.form]
       [(_ override (~var m (:method #'final-override))) #'m.form]
       [(_ override property (~var m (:property #'final-override-property))) #'m.form]
       [(_ (~var m (:method #'final))) #'m.form]))))
(define-syntax final-override 'placeholder)
(define-syntax final-property 'placeholder)
(define-syntax final-override-property 'placeholder)

(define-syntax method
  (make-class+interface-clause-transformer
   ;; class clause
   (lambda (stx data)
     (syntax-parse stx
       [(_ (~var m (:method #'method))) #'m.form]))
   ;; interface clause
   (lambda (stx data)
     (syntax-parse stx
       [(_ (~var m (:method #'method))) #'m.form]
       [(_ decl::method-decl) (wrap-class-clause #'(abstract decl.id decl.rhs decl.maybe-ret))]))))

(define-syntax property
  (make-class+interface-clause-transformer
   ;; class clause
   (lambda (stx data)
     (syntax-parse stx
       [(_ (~var m (:property #'property))) #'m.form]))
   ;; interface clause
   (lambda (stx data)
     (syntax-parse stx
       [(_ (~var m (:property #'property))) #'m.form]
       [(_ decl::property-decl) (wrap-class-clause #'(abstract-property decl.id decl.rhs decl.maybe-ret))]))))

(define-syntax override
  (make-class+interface-clause-transformer
   ;; class clause
   (lambda (stx data)
     (syntax-parse stx
       #:literals (method)
       [(_ method (~var m (:method #'override))) #'m.form]
       [(_ property (~var m (:property #'override-property))) #'m.form]
       [(_ (~var m (:method #'override))) #'m.form]))
   (lambda (stx data)
     (syntax-parse stx
       #:literals (method)
       [(_ method (~var m (:method #'override))) #'m.form]
       [(_ method decl::method-decl) (wrap-class-clause #'(abstract-override decl.id decl.rhs decl.maybe-ret))]
       [(_ property (~var m (:property #'override-property))) #'m.form]
       [(_ property decl::property-decl) (wrap-class-clause #'(abstract-override-property decl.id decl.rhs decl.maybe-ret))]
       [(_ (~var m (:method #'override))) #'m.form]
       [(_ decl::method-decl) (wrap-class-clause #'(abstract-override decl.id decl.rhs decl.maybe-ret))]))))
(define-syntax override-property 'placeholder)

(define-syntax private
  (make-class+interface-clause-transformer
   ;; class clause
   (lambda (stx data)
     (syntax-parse stx
       #:literals (implements method override property)
       [(_ (~and tag implements) form ...)
        (wrap-class-clause #`(private-implements . #,(parse-multiple-names #'(tag form ...))))]
       [(_ method (~var m (:method #'private))) #'m.form]
       [(_ override (~var m (:method #'private-override))) #'m.form]
       [(_ override method (~var m (:method #'private-override))) #'m.form]
       [(_ property (~var m (:property #'private-property))) #'m.form]
       [(_ override property (~var m (:property #'private-override-property))) #'m.form]
       [(_ (~and (~seq field _ ...) (~var f (:field 'private)))) #'f.form]
       [(_ (~var m (:method #'private))) #'m.form]))
   ;; interface clause
   (lambda (stx data)
     (syntax-parse stx
       #:literals (method)
       [(_ method (~var m (:method #'private))) #'m.form]
       [(_ (~var m (:method #'private))) #'m.form]))))
(define-syntax private-implements 'placeholder)
(define-syntax private-override 'placeholder)
(define-syntax private-property 'placeholder)
(define-syntax private-override-property 'placeholder)

(define-syntax abstract
  (make-class+interface-clause-transformer
   (lambda (stx data)
     (syntax-parse stx
       #:literals (method override property)
       [(_ method decl::method-decl) (wrap-class-clause #'(abstract decl.id decl.rhs decl.maybe-ret))]
       [(_ property decl::property-decl) (wrap-class-clause #'(abstract-property decl.id decl.rhs decl.maybe-ret))]
       [(_ override decl::method-decl) (wrap-class-clause #'(abstract-override decl.id decl.rhs decl.maybe-ret))]
       [(_ override method decl::method-decl) (wrap-class-clause #'(abstract-override decl.id decl.rhs decl.maybe-ret))]
       [(_ override property decl::property-decl) (wrap-class-clause #'(abstract-override-property decl.id decl.rhs decl.maybe-ret))]
       [(_ decl::method-decl) (wrap-class-clause #'(abstract decl.id decl.rhs decl.maybe-ret))]))))
(define-syntax abstract-property 'placeholder)
(define-syntax abstract-override 'placeholder)
(define-syntax abstract-override-property 'placeholder)

(define-for-syntax (same-return-signature? a b)
  (cond
    [(identifier? a)
     (and (identifier? b)
          (free-identifier=? a b))]
    [(identifier? b) #f]
    [(syntax? a)
     (same-return-signature? (syntax-e a) b)]
    [(syntax? b)
     (same-return-signature? a (syntax-e b))]
    [(null? a) (null? b)]
    [(pair? a)
     (and (pair? b)
          (and (same-return-signature? (car a) (car b))
               (same-return-signature? (cdr a) (cdr b))))]
    [else (equal? a b)]))

(define (not-assignable name)
  (error name "property does not support assignment"))
