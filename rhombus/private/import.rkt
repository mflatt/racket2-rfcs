#lang racket/base
(require (for-syntax racket/base
                     syntax/parse
                     racket/symbol
                     enforest
                     enforest/operator
                     enforest/transformer
                     enforest/property
                     enforest/syntax-local
                     enforest/name-parse
                     enforest/proc-name
                     syntax/modcollapse
                     "srcloc.rkt"
                     "name-path-op.rkt"
                     "introducer.rkt"
                     "realm.rkt"
                     "import-invert.rkt")
         "name-root.rkt"
         "name-root-ref.rkt"
         (submod "module-path.rkt" for-import-export)
         "definition.rkt"
         "dot.rkt"
         (submod "dot.rkt" for-dot-provider)
         "import-lower-require.rkt"
         "import-from-root.rkt"
         (only-in "implicit.rkt"
                  #%literal)
         (only-in "arithmetic.rkt"
                  [/ rhombus/]))

(provide import

         (for-space rhombus/import
                    #%juxtapose
                    #%literal
                    (rename-out [rhombus/ /]
                                [rhombus-file file]
                                [rhombus-lib lib]
                                [rhombus. |.|])
                    as
                    open
                    expose
                    rename
                    only
                    except
                    for_meta
                    for_label))

(module+ for-meta
  (provide (for-syntax import-modifier
                       import-modifier-block
                       in-import-space)))

(begin-for-syntax
  (property import-prefix-operator prefix-operator)
  (property import-infix-operator infix-operator)

  (struct import-prefix+infix-operator (prefix infix)
    #:property prop:import-prefix-operator (lambda (self) (import-prefix+infix-operator-prefix self))
    #:property prop:import-infix-operator (lambda (self) (import-prefix+infix-operator-infix self)))


  (property import-modifier transformer)
  (property import-modifier-block transformer)

  (define in-import-space (make-interned-syntax-introducer/add 'rhombus/import))

  (define (check-import-result form proc)
    (unless (syntax? form) (raise-result-error* (proc-name proc) rhombus-realm "Syntax" form))
    form)

  (define (make-identifier-import id)
    (unless (module-path? (syntax-e id))
      (raise-syntax-error 'import
                          "not a valid module path element, and not bound as a namespace"
                          id))
    id)

  (define-enforest
    #:syntax-class :import
    #:desc "import"
    #:operator-desc "import operator"
    #:in-space in-import-space
    #:name-path-op name-path-op
    #:name-root-ref name-root-ref
    #:name-root-ref-root name-root-ref-root
    #:prefix-operator-ref import-prefix-operator-ref
    #:infix-operator-ref import-infix-operator-ref
    #:check-result check-import-result
    #:make-identifier-form make-identifier-import)

  (define (make-import-modifier-ref transform-in req)
    ;; "accessor" closes over `req`:
    (lambda (v)
      (define mod (or (import-modifier-ref v)
                      (import-modifier-block-ref v)))
      (and mod
           (transformer (lambda (stx)
                          ((transformer-proc mod) (transform-in req) stx))))))

  (define-transform
    #:syntax-class (:import-modifier req)
    #:desc "import modifier"
    #:in-space in-import-space
    #:name-path-op name-path-op
    #:name-root-ref name-root-ref
    #:name-root-ref-root name-root-ref-root
    #:transformer-ref (make-import-modifier-ref transform-in req))

  (define (extract-prefixes r)
    (let extract ([r r] [accum null])
      (syntax-parse r
        #:datum-literals (rename-in only-in except-in expose-in rhombus-prefix-in for-meta for-label only-space-in)
        [#f (reverse accum)]
        [((~or rename-in only-in except-in expose-in for-label) mp . _) (extract #'mp accum)]
        [(rhombus-prefix-in mp name) (extract #'mp (cons r accum))]
        [((~or for-meta only-space-in) _ mp) (extract #'mp accum)]
        [_ (raise-syntax-error 'import
                               "don't know how to extract module path"
                               r)])))

  (define (extract-prefix mp r)
    (define prefixes (extract-prefixes r))
    (define (extract-string-prefix mp)
      (datum->syntax
       mp
       (string->symbol
        (regexp-replace #rx"[.].*$"
                        (regexp-replace #rx"^.*/" (syntax-e mp) "")
                        ""))
       mp))
    (cond
      [(null? prefixes)
       (syntax-parse mp
         #:datum-literals (lib import-root import-dotted import-spaces file reimport singleton)
         [_:string (extract-string-prefix mp)]
         [_:identifier (datum->syntax
                        mp
                        (string->symbol (regexp-replace #rx"^.*/"
                                                        (symbol->string (syntax-e mp))
                                                        ""))
                        mp)]
         [(lib str) (extract-string-prefix #'str)]
         [(import-root id . _) #'id]
         [(import-dotted _ id) #'id]
         [(import-spaces mp . _) #'mp]
         [(reimport id . _) #'id]
         [(singleton _ id) #'id]
         [(file str) (let-values ([(base name dir?) (split-path (syntax-e #'str))])
                       (datum->syntax
                        mp
                        (string->symbol (path->string (path-replace-suffix name #"")))))]
         [_ (raise-syntax-error 'import
                                "don't know how to extract default prefix"
                                mp)])]
      [(null? (cdr prefixes))
       (syntax-parse (car prefixes)
         [(_ mp name) #'name])]
      [else
       (raise-syntax-error 'import
                           "second prefix specification not allowed"
                           (cadr prefixes))]))

  (define (apply-modifiers mods r-parsed)
    (cond
      [(null? mods) r-parsed]
      [else
       (syntax-parse (car mods)
         #:datum-literals (group)
         [(~var im (:import-modifier r-parsed))
          (apply-modifiers (cdr mods) #'im.parsed)]
         [(group form . _)
          (raise-syntax-error #f
                              "not an import modifier"
                              #'form)])]))

  (define-syntax-class :modified-imports
    #:datum-literals (group block)
    (pattern (group mod-id:identifier mod-arg ... (block imp ...))
             #:when (syntax-local-value* (in-import-space #'mod-id) import-modifier-ref)
             #:attr mod #'(group mod-id mod-arg ...))))

(define-syntax import
  (definition-transformer
   (lambda (stx)
     (syntax-parse stx
       [(_ (block r ...))
        #'((rhombus-import () r ...))]))))

(define-syntax (rhombus-import stx)
  ;; handle one import group at a time, so it can import
  ;; transformers that are used for later imports
  (syntax-parse stx
    [(_ _) #'(begin)]
    [(_ mods mi::modified-imports . more)
     #`(begin
         (rhombus-import (mi.mod . mods) mi.imp)
         ...
         (rhombus-import mods . more))]
    [(_ mods r::import . more)
     ;; apply modifiers, but then flip around to extract
     ;; module path from the modifiers
     (define r-parsed (apply-modifiers (reverse (syntax->list #'mods))
                                       #'r.parsed))
     (define-values (mod-path-stx r-stx) (import-invert r-parsed))
     #`(begin
         (rhombus-import-one #hasheq() #,mod-path-stx #,r-stx (no-more wrt-placeholder))
         (rhombus-import mods . more))]))

;; Uses a continuation form to thread through the module path that
;; accessed-via-dots module paths are relative to and to thread
;; through a dotted path prefix. When a dot prefix is used, then we
;; get an `import-spaces` form, which can have a mixture of name
;; roots, modules (to re-import), and singletons, and we have to sort
;; out that mixture here.
(define-syntax (rhombus-import-one stx)
  (syntax-parse stx
    #:datum-literals (import-dotted import-root import-spaces singleton)
    [(_ wrt ((~literal import-dotted) mod-path id) r k)
     #:with m-mod-path (syntax-local-introduce #'mod-path)
     #:with m-id (syntax-local-introduce #'id)
     #`(begin
         (rhombus-import-one wrt m-mod-path (rhombus-prefix-in #f #f)
                             (rhombus-import-dotted-one wrt m-id id r k)))]
    [(_ wrt (import-spaces ir ...) r (k-form write-placeholder . k-args))
     ;; Split into the three types:
     (define-values (mods hiers sings) (split-imports (syntax->list #'(ir ...))))
     ;; For each space where the import is a module, collapse
     ;; module paths to deal with import changes
     (define new-wrt
       (for/fold ([wrt (syntax-e #'wrt)])
                 ([mod (in-list mods)])
         (syntax-parse mod
           [(space mp)
            (hash-set (if (eq? '#:all (syntax-e #'space))
                          #hasheq()
                          wrt)
                      (syntax-e #'space)
                      (collapse-path #'mp (or (hash-ref wrt (syntax-e #'space) #f)
                                              (hash-ref wrt '#:all #'#f))))])))
     ;; Mixtures of modules and non-module or multiple module paths: handled,
     ;; but beware that the bindings are in different scopes (so that module-based
     ;; imports can be shadowed). To handle the mixture, we thread a consistent
     ;; `covered-ht` through both module and non-module imports.
     ;; Meanwhile, report an error for any work on content that's
     ;; applied to a singleton import by itself:
     (unless (or (pair? mods) (pair? hiers))
       (convert-require-from-root #'r #hasheq() #hasheq() #f))
     ;; module re-imports
     (define-values (mod-forms covered-ht)
       (let loop ([mods mods] [rev-mod-forms '()] [covered-ht #hasheq()])
         (cond
           [(null? mods) (values (reverse rev-mod-forms) covered-ht)]
           [else
            (define mod (car mods))
            (define-values (mod-form new-covered-ht)
              (syntax-parse mod
                [(space mp)
                 (define prefix (extract-prefix #'mp #'r))
                 ;; The name-root expansion of import prefixes is handled by
                 ;; `name-root-ref`, which recognizes `(portal <id> (import ....))`
                 ;; forms generated by `lower-require-clause`
                 (lower-require-clause (if (eq? (syntax-e #'space) '#:all)
                                           #'r
                                           #'(only-space-in space r))
                                       (hash-ref new-wrt (syntax-e #'space))
                                       (and (syntax-e prefix)
                                            prefix)
                                       covered-ht
                                       (or (pair? (cdr mods))
                                           (pair? hiers)))]))
            (loop (cdr mods) (cons mod-form rev-mod-forms) new-covered-ht)])))
     ;; name roots
     (define name-root-forms
       (let loop ([irs hiers] [covered-ht covered-ht])
         (cond
           [(null? irs) null]
           [else
            (syntax-parse (car irs)
              [(space im)
               (define-values (form new-covered-ht) (imports-from-root #'im #'r covered-ht (pair? (cdr irs))
                                                                       (eq? #f (syntax-e #'space))))
               (cons form
                     (loop (cdr irs) new-covered-ht))])])))
     #`(begin
         #,@mod-forms
         #,@name-root-forms
         ;; singletons
         #,@(for/list ([sing (in-list sings)])
              (syntax-parse sing
                #:datum-literals (singleton)
                [(space (~and mp (singleton id as-id)))
                 (define prefix (extract-prefix #'mp #'r))
                 (cond
                   [(syntax-e prefix)
                    (define intro (if (syntax-e #'space)
                                      (make-interned-syntax-introducer/add (syntax-e #'space))
                                      (lambda (x) x)))
                    (import-singleton #'id (intro prefix))]
                   [(or (pair? mods) (pair? hiers))
                    #'(begin)]
                   [else
                    (raise-syntax-error #f
                                        "cannot open binding that is not a namespace"
                                        #'id)])]))
         (k-form #,new-wrt . k-args))]
    [(_ wrt mp r k)
     #'(rhombus-import-one wrt (import-spaces (#:all mp)) r k)]))

(define-syntax (rhombus-import-dotted-one stx)
  (syntax-parse stx
    [(_ wrt lookup-id id r k)
     #`(rhombus-import-one wrt #,(name-root-as-import stx #'lookup-id #'id #t) r k)]))

(define-for-syntax (name-root-as-import stx lookup-id id as-field?)
  (define space+maps
    (for/list ([space-sym (in-list (cons #f (syntax-local-module-interned-scope-symbols)))]
               #:do[(define intro (if space-sym
                                      (make-interned-syntax-introducer/add space-sym)
                                      (lambda (id) id)))
                    (define space-id (intro lookup-id))
                    (define i (and (or (not as-field?)
                                       (identifier-distinct-binding space-id (intro id)))
                                   (or (not space-sym)
                                       (identifier-distinct-binding space-id lookup-id))
                                   (or (syntax-local-value* space-id import-root-ref)
                                       (and (identifier-distinct-binding space-id (if as-field? (intro id) lookup-id))
                                            'other))))]
               #:when i)
      (list space-sym
            (if (eq? i 'other)
                #`(singleton #,space-id #,(intro id))
                (syntax-parse i
                  #:datum-literals (parsed map)
                  [(parsed mod-path parsed-r) #`(reimport #,id #,(syntax-local-introduce (transform-in #'parsed-r)))]
                  [(map . _) #`(import-root #,(intro id) #,i #,space-id)])))))
  (cond
    [(null? space+maps)
     (if as-field?
         (raise-syntax-error #f
                             (string-append "not provided as a namespace")
                             id)
         (raise-syntax-error #f
                             (string-append "not bound as a namespace")
                             stx
                             id))]
    [else
     #`(import-spaces #,@space+maps)]))

(define-for-syntax (split-imports irs)
  (let loop ([irs irs] [rev-mods '()] [rev-hiers '()] [rev-sings '()])
    (cond
      [(null? irs) (values (reverse rev-mods) (reverse rev-hiers) (reverse rev-sings))]
      [else
       (define ir (car irs))
       (syntax-parse ir
         #:datum-literals (import-root singleton)
         [(_ (import-root . _))
          (loop (cdr irs) rev-mods (cons ir rev-hiers) rev-sings)]
         [(_ (singleton . _))
          (loop (cdr irs) rev-mods rev-hiers (cons ir rev-sings))]
         [_
          (loop (cdr irs) (cons ir rev-mods) rev-hiers rev-sings)])])))

(define-for-syntax (imports-from-root im r-parsed covered-ht accum? open-all-spaces?)
  (syntax-parse im
    #:datum-literals (import-root map)
    [(import-root id (map orig-id [key val] ...) lookup-id)
     (define prefix (extract-prefix #'id r-parsed))
     (define-values (ht expose-ht new-covered-ht)
       (convert-require-from-root
        r-parsed
        (for/hasheq ([key (in-list (syntax->list #'(key ...)))]
                     [val (in-list (syntax->list #'(val ...)))]
                     #:when (syntax-e key))
          (values (syntax-e key) val))
        covered-ht
        accum?))
     (define bound-prefix (string-append (symbol->immutable-string (syntax-e #'id))
                                         "."))
     (define extension-ht
       (for*/fold ([ht #hasheq()]) ([space-sym (in-list (cons #f (syntax-local-module-interned-scope-symbols)))]
                                    #:do [(define intro (if space-sym
                                                            (make-interned-syntax-introducer/add space-sym)
                                                            (lambda (x) x)))]
                                    [sym (in-list (syntax-bound-symbols #'lookup-id))]
                                    #:do [(define str (symbol->immutable-string sym))]
                                    #:when (and (> (string-length str) (string-length bound-prefix))
                                                (string=? bound-prefix (substring str 0 (string-length bound-prefix)))))
         (define ext-id (datum->syntax #'lookup-id sym #'id))
         (define id+intros (hash-ref ht sym null))
         (cond
           [(ormap (lambda (id+intro)
                     (free-identifier=? (car id+intro) ext-id))
                   id+intros)
            ;; already found a binding that covers this one
            ht]
           [else
            (hash-set ht sym (cons (cons ext-id intro) id+intros))])))
     (values
      #`(begin
          ;; non-exposed
          #,@(if (syntax-e prefix)
                 (with-syntax ([(root-id) (generate-temporaries #'(id))])
                   #`((define-name-root root-id
                        #:orig-id orig-id
                        #:root-as-rename #,(for/or ([key (in-list (syntax->list #'(key ...)))]
                                                    [val (in-list (syntax->list #'(val ...)))]
                                                    #:when (not (syntax-e key)))
                                             val)
                        #:fields
                        #,(for/list ([(key val) (in-hash ht)])
                            #`[#,key #,val]))
                      (define-syntax #,(datum->syntax #'id (syntax-e prefix) #'id)
                        (make-rename-transformer (quote-syntax root-id)))
                      ;; If there are no renames, this could replace the above:
                      #;
                      #,@(let ([new-id (datum->syntax #'id (syntax-e prefix) #'id)])
                           (if (bound-identifier=? new-id #'lookup-id)
                               '()
                               #`((define-syntax #,new-id (make-rename-transformer (quote-syntax lookup-id))))))
                      ;; Additional imports for namespace extensions
                      #,@(for*/list ([ext-id+intros (in-hash-values extension-ht)]
                                     [ext-id+intro (in-list ext-id+intros)]
                                     #:do [(define ext-id (car ext-id+intro))
                                           (define intro (cdr ext-id+intro))
                                           (define new-id
                                             (intro
                                              (datum->syntax #'id
                                                             (string->symbol
                                                              (string-append (symbol->immutable-string (syntax-e prefix))
                                                                             "."
                                                                             (substring
                                                                              (symbol->immutable-string (syntax-e ext-id))
                                                                              (string-length bound-prefix))))
                                                             #'id)))]
                                     #:unless (bound-identifier=? new-id ext-id))
                           #`(define-syntax #,new-id
                               (make-rename-transformer (quote-syntax #,ext-id))))))
                 null)
          ;; exposed
          #,@(for/list ([space-sym (in-list (cond
                                              [open-all-spaces?
                                               (cons #f (syntax-local-module-interned-scope-symbols))]
                                              [else (list #f)]))]
                        #:do [(define intro (if space-sym
                                                (make-interned-syntax-introducer space-sym)
                                                (lambda (x mode) x)))]
                        [key (in-hash-keys (if (syntax-e prefix) expose-ht ht))]
                        #:do [(define val (hash-ref ht key))
                              (define space-val (intro val 'add))]
                        #:when (and (identifier-binding space-val)
                                    (or (not open-all-spaces?)
                                        (not space-sym)
                                        (not (free-identifier=? space-val (intro val 'remove))))))
               #`(define-syntax #,(intro (datum->syntax #'id key #'id) 'add)
                   (make-rename-transformer (quote-syntax #,space-val)))))
      new-covered-ht)]))

(define-for-syntax (import-singleton id as-id)
  (cond
    [(bound-identifier=? id as-id)
     #'(begin)]
    [else
     #`(define-syntax #,as-id (make-rename-transformer (quote-syntax #,id)))]))

;; "done" continuation for `rhombus-import-one`
(define-syntax (no-more stx) #'(begin))

(define-for-syntax (collapse-path mp wrt)
  (define unwrapped-mp (syntax-parse mp
                         #:datum-literals (reimport)
                         [(reimport _ mp) #'mp]
                         [_ mp]))
  (define plain-mp (syntax-parse unwrapped-mp
                     #:datum-literals (only-space-in)
                     [(only-space-in _ mp) #'mp]
                     [_ unwrapped-mp]))
  (cond
    [(not (syntax-e wrt)) plain-mp]
    [else (datum->syntax plain-mp
                         (collapse-module-path (syntax->datum plain-mp) (syntax->datum wrt))
                         plain-mp
                         plain-mp)]))
  
(define-syntax (define-import-syntax stx)
  (syntax-parse stx
    [(_ name:id rhs)
     (quasisyntax/loc stx
       (define-syntax #,(in-import-space #'name) rhs))]))

(define-import-syntax #%juxtapose
  (import-infix-operator
   #'#%juxtapose
   '((default . weaker))
   'macro
   (lambda (form1 stx)
     (syntax-parse stx
       #:datum-literals (block group)
       [(_ (block mod ...))
        (values (apply-modifiers (syntax->list #'(mod ...))
                                 form1)
                #'())]
       [(_ mod-id:identifier mod-arg ... (block mod ...))
        #:when (syntax-local-value* (in-import-space #'mod-id) import-modifier-ref)
        (values (apply-modifiers (syntax->list #'((group mod-id mod-arg ...) mod ...))
                                 form1)
                #'())]
       [(_ mod ...)
        (values (apply-modifiers (syntax->list #'((group mod ...)))
                                 form1)
                #'())]))
   'left))

(define-import-syntax #%literal
  (make-module-path-literal-operator import-prefix-operator))

(define-import-syntax rhombus/
  (make-module-path-/-operator import-infix-operator))

(define-import-syntax rhombus-file
  (make-module-path-file-operator import-prefix-operator))

(define-import-syntax rhombus-lib
  (make-module-path-lib-operator import-prefix-operator))

(define-import-syntax rhombus.
  (import-prefix+infix-operator
   (import-prefix-operator
    #'rhombus.
    '((default . weaker))
    'macro
    (lambda (stx)
      (syntax-parse stx
        [(_ id:identifier . tail)
         (values (name-root-as-import stx #'id #'id #f)
                 #'tail)]
        [_
         (raise-syntax-error #f
                             "expected an identifier"
                             stx)])))
   (import-infix-operator
    #'rhombus.
    '((default . weaker))
    'macro
    ;; infix
    (lambda (form1 stx)
      (syntax-parse stx
        [(_ id:identifier . tail)
         (values #`(import-dotted #,form1 id)
                 #'tail)]
        [else
         (raise-syntax-error #f "not ready, yet" stx)]))
    'left)))

(define-import-syntax as
  (import-modifier
   (lambda (req stx)
     (syntax-parse stx
       [(_ name:identifier)
        (datum->syntax req
                       (list #'rhombus-prefix-in req #'name)
                       req)]))))

(begin-for-syntax
  (define-syntax-class :as-id
    #:description "`as`"
    (pattern as-id:identifier
             #:when (free-identifier=? (in-import-space #'as) (in-import-space #'as-id)))))
    
(define-import-syntax rename
  (import-modifier-block
   (lambda (req stx)
     (syntax-parse stx
       #:datum-literals (block)
       [(_ (block (group int::name _::as-id ext::name)
                  ...))
        (datum->syntax req
                       (list* #'rename-in req #'([int.name ext.name] ...))
                       req)]))))

(define-import-syntax only
  (import-modifier-block
   (lambda (req stx)
     (syntax-parse stx
       #:datum-literals (block group)
       [(_ (block (group name::name ...) ...))
        (datum->syntax req
                       (list* #'only-in req #'(name.name ... ...))
                       req)]))))

(define-import-syntax except
  (import-modifier-block
   (lambda (req stx)
     (syntax-parse stx
       #:datum-literals (block group)
       [(_ (block (group name::name ...) ...))
        (datum->syntax req
                       (list* #'except-in req #'(name.name ... ...))
                       req)]))))

(define-import-syntax open
  (import-modifier
   (lambda (req stx)
     (syntax-parse stx
       #:datum-literals (block group)
       [(_)
        (datum->syntax req
                       (list #'rhombus-prefix-in req #f)
                       req)]))))

(define-import-syntax expose
  (import-modifier-block
   (lambda (req stx)
     (syntax-parse stx
       #:datum-literals (block group)
       [(_ (block (group name::name ...) ...))
        (datum->syntax req
                       (list* #'expose-in req #'(name.name ... ...))
                       req)]))))

(define-import-syntax for_meta
  (import-modifier
   (lambda (req stx)
     (syntax-parse stx
       [(form phase)
        (define ph (syntax-e #'phase))
        (unless (exact-integer? ph)
          (raise-syntax-error #f "not a valid phase" stx #'phase))
        (datum->syntax req (list (syntax/loc #'form for-meta) #'phase req) req)]
       [(form) 
        (datum->syntax req (list (syntax/loc #'form for-meta) #'1 req) req)]))))

(define-import-syntax for_label
  (import-modifier
   (lambda (req stx)
     (syntax-parse stx
       [(form) 
        (datum->syntax req (list (syntax/loc #'form for-meta) #f req) req)]))))
