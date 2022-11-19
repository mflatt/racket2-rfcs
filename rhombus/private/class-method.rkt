#lang racket/base
(require (for-syntax racket/base
                     syntax/parse
                     racket/stxparam-exptime
                     enforest/syntax-local
                     "class-parse.rkt"
                     "interface-parse.rkt"
                     "tag.rkt"
                     "srcloc.rkt")
         racket/stxparam
         "expression.rkt"
         "parse.rkt"
         "entry-point.rkt"
         "class-this.rkt"
         "class-method-result.rkt"
         "function-arity-key.rkt"
         "dot-provider-key.rkt"
         "static-info.rkt"
         (submod "dot.rkt" for-dot-provider)
         "assign.rkt"
         "parens.rkt"
         (submod "function.rkt" for-call)
         "realm.rkt")

(provide (for-syntax extract-method-tables
                     build-interface-vtable
                     build-quoted-method-map
                     build-quoted-method-shapes
                     build-method-results
                     build-method-result-expression
                     build-methods

                     get-private-table)

         this
         super

         prop:methods
         prop-methods-ref
         method-ref
         method-curried-ref

         raise-not-an-instance)

(define-values (prop:methods prop-methods? prop-methods-ref)
  (make-struct-type-property 'methods))

(define-syntax (method-ref stx)
  (syntax-parse stx
    [(_ ref obj pos) #`(vector-ref (ref obj) pos)]))

(define (method-curried-ref ref obj pos)
  (curry-method (method-ref ref obj pos) obj))

(define (raise-not-an-instance name v)
  (raise-argument-error* name rhombus-realm "not an instance for method call" v))

;; Results:
;;   method-mindex   ; symbol -> mindex
;;   method-names    ; index -> symbol-or-identifier
;;   method-vtable   ; index -> function-identifier or '#:abstract
;;   method-results  ; symbol -> nonempty list of identifiers; first one implies others
;;   method-private  ; symbol -> identifier or (list identifier); list means property
;;   method-decls    ; symbol -> identifier, intended for checking distinct
;;   abstract-name   ; #f or identifier for a still-abstract method

(define-for-syntax (extract-method-tables stx added-methods super interfaces private-interfaces final?)
  (define supers (if super (cons super interfaces) interfaces))
  (define-values (super-str supers-str)
    (cond
      [(null? interfaces)
       (values "superclass" "superclasses(!?)")]
      [(not super)
       (values "interface" "superinterfaces")]
      [else
       (values "class or interface" "classes or superinterfaces")]))

  ;; create merged method tables from the superclass (if any) and all superinterfaces;
  ;; we start with the superclass, if any, so the methods from its vtable stay
  ;; in the same place in the new vtable
  (define-values (ht            ; symbol -> (cons mindex id)
                  super-priv-ht ; symbol -> identifier or (list identifier), implies not in `ht`
                  vtable-ht)    ; int -> accessor-identifier or '#:abstract
    (for/fold ([ht #hasheq()] [priv-ht #hasheq()] [vtable-ht #hasheqv()]) ([super (in-list supers)])
      (define super-vtable (super-method-vtable super))
      (define private? (hash-ref private-interfaces super #f))
      (for/fold ([ht ht] [priv-ht priv-ht] [vtable-ht vtable-ht])
                ([shape (super-method-shapes super)]
                 [super-i (in-naturals)])
        (define i (hash-count ht))
        (define new-rhs (let ([rhs (vector-ref super-vtable super-i)])
                          (if (eq? (syntax-e rhs) '#:abstract) '#:abstract rhs)))
        (define-values (key val)
          (let* ([property? (pair? shape)]
                 [shape (if (pair? shape) (car shape) shape)]
                 [final? (not (box? shape))]
                 [shape (if (box? shape) (unbox shape) shape)])
            (values shape (cons (mindex i final? property?) shape))))
        (define old-val (or (hash-ref ht key #f)
                            (hash-ref priv-ht key #f)))
        (cond
          [old-val
           (define old-rhs (cond
                             [(and (pair? old-val)
                                   (mindex? (car old-val)))
                              (let ([old-i (car old-val)])
                                (hash-ref vtable-ht (mindex-index old-i)))]
                             [(pair? old-val) (car old-val)]
                             [else old-val]))
           (unless (or (if (identifier? old-rhs)
                           (and (identifier? new-rhs)
                                (free-identifier=? old-rhs new-rhs))
                           (eq? old-rhs new-rhs))
                       (for/or ([added (in-list added-methods)])
                         (and (eq? key (syntax-e (added-method-id added)))
                              (eq? 'override (added-method-mode added)))))
             (raise-syntax-error #f (format "method supplied by multiple ~a and not overridden" supers-str) stx key))
           (if (or private?
                   (and (pair? old-val) (mindex? (car old-val))))
               (values ht priv-ht vtable-ht)
               (values (hash-set vtable-ht key val)
                       (hash-remove priv-ht key)
                       (hash-set vtable-ht i new-rhs)))]
          [private?
           (values ht
                   (hash-set priv-ht key (if (pair? shape) ; => property
                                             (list new-rhs)
                                             new-rhs))
                   vtable-ht)]
          [else
           (values (hash-set ht key val)
                   priv-ht
                   (hash-set vtable-ht i new-rhs))]))))

  ;; merge method-result tables from superclass and superinterfaces,
  ;; assuming that the names all turn out to be sufficiently distinct
  (define super-method-results
    (for/fold ([method-results (if super
                                   (for/hasheq ([(sym id) (in-hash (class-desc-method-result super))])
                                     (values sym (list id)))
                                   #hasheq())])
              ([intf (in-list interfaces)])
      (for/fold ([method-results method-results]) ([(sym id) (in-hash (interface-desc-method-result intf))])
        (hash-set method-results sym (cons id (hash-ref method-results sym '()))))))

  ;; add methods for the new class/interface
  (define-values (new-ht new-vtable-ht priv-ht here-ht)
    (for/fold ([ht ht] [vtable-ht vtable-ht] [priv-ht #hasheq()] [here-ht #hasheq()]) ([added (in-list added-methods)])
      (define id (added-method-id added))
      (define new-here-ht (hash-set here-ht (syntax-e id) id))
      (define (check-consistent-property property?)
        (if property?
            (when (eq? (added-method-kind added) 'method)
              (raise-syntax-error #f (format "cannot override ~a's property with a non-property method" super-str)
                                  stx id))
            (when (eq? (added-method-kind added) 'property)
              (raise-syntax-error #f (format "cannot override ~a's non-property method with a property" super-str)
                                  stx id))))
      (cond
        [(hash-ref here-ht (syntax-e id) #f)
         (raise-syntax-error #f "duplicate method name" stx id)]
        [(hash-ref ht (syntax-e id) #f)
         => (lambda (mix+id)
              (define mix (car mix+id))
              (cond
                [(eq? 'override (added-method-mode added))
                 (when (eq? (added-method-disposition added) 'private)
                   (raise-syntax-error #f (format "method is not in private ~a" super-str) stx id))
                 (when (mindex-final? mix)
                   (raise-syntax-error #f (format "cannot override ~a's final method" super-str) stx id))
                 (check-consistent-property (mindex-property? mix))
                 (values (if (eq? (added-method-disposition added) 'final)
                             (let ([property? (eq? (added-method-kind added) 'property)])
                               (hash-set ht (syntax-e id) (cons (mindex mix #t property?) id)))
                             ht)
                         (hash-set vtable-ht (mindex-index mix) (added-method-rhs-id added))
                         priv-ht
                         new-here-ht)]
                [else
                 (raise-syntax-error #f (format "method is already in ~a" super-str) stx id)]))]
        [(hash-ref super-priv-ht (syntax-e id) #f)
         => (lambda (rhs)
              (cond
                [(and (eq? (added-method-mode added) 'override)
                      (eq? (added-method-disposition added) 'private))
                 (check-consistent-property (list? rhs))
                 (values ht
                         vtable-ht
                         (hash-set priv-ht (syntax-e id) (let ([id (added-method-rhs-id added)])
                                                           (if (eq? (added-method-kind added) 'property)
                                                               (list id)
                                                               id)))
                         new-here-ht)]
                [(eq? (added-method-mode added) 'override)
                 (raise-syntax-error #f (format "method is in private ~a" super-str) stx id)]
                [else
                 (raise-syntax-error #f (format "method is already in private ~a" super-str) stx id)]))]
        [else
         (cond
           [(eq? (added-method-mode added) 'override)
            (raise-syntax-error #f (format "method is not in ~a" super-str) stx id)]
           [(eq? (added-method-disposition added) 'private)
            (values ht
                    vtable-ht
                    (hash-set priv-ht (syntax-e id) (let ([id (added-method-rhs-id added)])
                                                      (if (eq? (added-method-kind added) 'property)
                                                          (list id)
                                                          id)))
                    new-here-ht)]
           [else
            (define pos (hash-count vtable-ht))
            (values (hash-set ht (syntax-e id)
                              (cons (mindex pos
                                            (or final?
                                                (eq? (added-method-disposition added) 'final))
                                            (eq? (added-method-kind added) 'property))
                                    id))
                    (hash-set vtable-ht pos (added-method-rhs-id added))
                    priv-ht
                    new-here-ht)])])))

  (for ([(name rhs) (in-hash super-priv-ht)])
    (when (eq? rhs '#:abstract)
      (unless (hash-ref priv-ht name #f)
        (raise-syntax-error #f (format "method from private ~a must be overridden" super-str) stx name))))

  (define method-mindex
    (for/hasheq ([(k mix+id) (in-hash new-ht)])
      (values k (car mix+id))))
  (define method-names
    (for/hasheqv ([(s mix+id) (in-hash new-ht)])
      (values (mindex-index (car mix+id)) (cdr mix+id))))
  (define method-vtable
    (for/vector ([i (in-range (hash-count new-vtable-ht))])
      (hash-ref new-vtable-ht i)))
  (define method-results
    (for/fold ([method-results super-method-results]) ([added (in-list added-methods)]
                                                       #:when (added-method-result-id added))
      (define sym (syntax-e (added-method-id added)))
      (hash-set method-results sym (cons (added-method-result-id added)
                                         (hash-ref method-results sym '())))))
  (define abstract-name
    (for/or ([v (in-hash-values new-vtable-ht)]
             [i (in-naturals)])
      (and (eq? v '#:abstract)
           (hash-ref method-names i))))

  (values method-mindex
          method-names
          method-vtable
          method-results
          priv-ht
          here-ht
          abstract-name))

(define-for-syntax (build-interface-vtable intf method-mindex method-vtable method-names method-private)
  (for/list ([shape (in-vector (interface-desc-method-shapes intf))])
    (define name (let* ([shape (if (pair? shape) (car shape) shape)]
                        [shape (if (box? shape) (unbox shape) shape)])
                   shape))
    (cond
      [(hash-ref method-private name #f)
       => (lambda (id) (if (pair? id) (car id) id))]
      [else
       (define pos (mindex-index (hash-ref method-mindex name)))
       (vector-ref method-vtable pos)])))

(define-for-syntax (build-quoted-method-map method-mindex)
  (for/hasheq ([(sym mix) (in-hash method-mindex)])
    (values sym (mindex-index mix))))

(define-for-syntax (build-quoted-method-shapes method-vtable method-names method-mindex)
  (for/vector ([i (in-range (vector-length method-vtable))])
    (define name (hash-ref method-names i))
    (define mix (hash-ref method-mindex (if (syntax? name) (syntax-e name) name)))
    ((if (mindex-property? mix) list values)
     ((if (mindex-final? mix) values box)
      name))))

(define-for-syntax (build-method-results added-methods
                                         method-mindex method-vtable method-private
                                         method-results)
  (for/list ([added (in-list added-methods)]
             #:when (added-method-result-id added))
    #`(define-method-result-syntax #,(added-method-result-id added)
        #,(added-method-maybe-ret added)
        #,(cdr (hash-ref method-results (syntax-e (added-method-id added))))
        ;; When calls do not go through vtable, also add static info
        ;; as #%call-result to binding:
        #,(or (let ([id/property (hash-ref method-private (syntax-e (added-method-id added)) #f)])
                (if (pair? id/property) (car id/property) id/property))
              (let ([mix (hash-ref method-mindex (syntax-e (added-method-id added)) #f)])
                (and (mindex-final? mix)
                     (vector-ref method-vtable (mindex-index mix))))))))
          
(define-for-syntax (build-method-result-expression method-result)
  #`(hasheq
     #,@(apply append
               (for/list ([(sym ids) (in-hash method-result)])
                 (list #`(quote #,sym)
                       #`(quote-syntax #,(car ids)))))))

(define-for-syntax (super-method-vtable p)
  (syntax-e
   (if (class-desc? p)
       (class-desc-method-vtable p)
       (interface-desc-method-vtable p))))

(define-for-syntax (super-method-shapes p)
  (if (class-desc? p)
      (class-desc-method-shapes p)
      (interface-desc-method-shapes p)))

(define-for-syntax (super-method-map p)
  (if (class-desc? p)
      (class-desc-method-map p)
      (interface-desc-method-map p)))

(define-syntax-parameter private-tables #f)

(define-syntax this
  (expression-transformer
   #'this
   (lambda (stxs)
     (syntax-parse stxs
       [(head . tail)
        (cond
          [(let ([v (syntax-parameter-value #'this-id)])
             (and (not (identifier? v)) v))
           => (lambda (id+dp+supers)
                (syntax-parse id+dp+supers
                  [(id dp . _)
                   (values (wrap-static-info (datum->syntax #'id (syntax-e #'id) #'head #'head)
                                             #'#%dot-provider
                                             #'dp)
                           #'tail)]))]
          [else
           (raise-syntax-error #f
                               "allowed only within methods"
                               #'head)])]))))

(define-syntax super
  (expression-transformer
   #'this
   (lambda (stxs)
     (define id-or-id+dp+supers (syntax-parameter-value #'this-id))
     (cond
       [(not id-or-id+dp+supers)
        (raise-syntax-error #f
                            "allowed only within methods and constructors"
                            #'head)]
       [(identifier? id-or-id+dp+supers)
        ;; in a constructor
        (syntax-parse stxs
          [(head . tail)
           (values id-or-id+dp+supers #'tail)])]
       [else
        ;; in a method
        (define id+dp+supers id-or-id+dp+supers)
        (syntax-parse stxs
          #:datum-literals (op |.|)
          [(head (op |.|) method-id:identifier (~and args (tag::parens arg ...)) . tail)
           (syntax-parse id+dp+supers
             [(id dp)
              (raise-syntax-error #f "class has no superclass" #'head)]
             [(id dp . super-ids)
              (define super+pos
                (for/or ([super-id (in-list (syntax->list #'super-ids))])
                  (define super (syntax-local-value* (in-class-desc-space super-id)
                                                     (lambda (v)
                                                       (or (class-desc-ref v)
                                                           (interface-desc-ref v)))))
                  (unless super
                    (raise-syntax-error #f "class or interface not found" super-id))
                  (define pos (hash-ref (super-method-map super) (syntax-e #'method-id) #f))
                  (and pos (cons super pos))))
              (unless super+pos
                (raise-syntax-error #f "no such method in superclass" #'head #'method-id))
              (define super (car super+pos))
              (define pos (cdr super+pos))
              (define impl (vector-ref (super-method-vtable super) pos))
              (when (eq? (syntax-e impl) '#:abstract)
                (raise-syntax-error #f "method is abstract in superclass" #'head #'method-id))
              (define-values (call new-tail)
                (parse-function-call impl (list #'id) #'(method-id args)))
              (values call #'tail)])])]))))

(define-for-syntax (get-private-tables)
  (let ([id (syntax-parameter-value #'private-tables)])
    (if id
        (syntax-local-value id)
        '())))

(define-for-syntax (get-private-table desc)
  (define tables (get-private-tables))
  (or (for/or ([t (in-list tables)])
        (and (free-identifier=? (car t) (class-desc-id desc))
             (cdr t)))
      #hasheq()))

(define-for-syntax (make-field-syntax id accessor-id maybe-mutator-id)
  (expression-transformer
   id
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (op)
       #:literals (:=)
       [(head (op :=) rhs ...)
        #:when (syntax-e maybe-mutator-id)
        (syntax-parse (syntax-parameter-value #'this-id)
          [(obj-id . _)
           (values (no-srcloc
                    #`(let ([#,id (rhombus-expression (#,group-tag rhs ...))])
                        #,(datum->syntax #'here
                                         (list maybe-mutator-id #'obj-id id)
                                         #'head
                                         #'head)
                        #,id))
                   #'())])]
       [(head . tail)
        (syntax-parse (syntax-parameter-value #'this-id)
          [(id . _)
           (values (datum->syntax #'here
                                  (list accessor-id #'id)
                                  #'head
                                  #'head)
                   #'tail)])]))))

(define-for-syntax (make-method-syntax id index/id result-id)
  (expression-transformer
   id
   (lambda (stx)
     (syntax-parse stx
       [(head (~and args (tag::parens arg ...)) . tail)
        (syntax-parse (syntax-parameter-value #'this-id)
          [(id . _)
           (define rator (if (identifier? index/id)
                             index/id
                             #`(vector-ref (prop-methods-ref id) #,index/id)))
           (define-values (call new-tail)
             (parse-function-call rator (list #'id) #'(head args)))
           (define r (and (syntax-e result-id)
                          (syntax-local-method-result result-id)))
           (define wrapped-call
             (if r
                 (wrap-static-info* call (method-result-static-infos r))
                 call))
           (values wrapped-call #'tail)])]
       [(head . _)
        (raise-syntax-error #f
                            "method must be called"
                            #'head)]))))

(define-for-syntax (build-methods method-results
                                  added-methods method-mindex method-names method-private
                                  names)
  (with-syntax ([(name name-instance name?
                       [field-name ...]
                       [name-field ...]
                       [maybe-set-name-field! ...]
                       [private-field-name ...]
                       [private-field-desc ...]
                       [super-name ...])
                 names])
    (with-syntax ([(field-name ...) (for/list ([id (in-list (syntax->list #'(field-name ...)))])
                                      (datum->syntax #'name (syntax-e id) id id))]
                  [((method-name method-index/id method-result-id) ...)
                   (for/list ([i (in-range (hash-count method-mindex))])
                     (define m-name (let ([n (hash-ref method-names i)])
                                      (if (syntax? n)
                                          (syntax-e n)
                                          n)))
                     (define mix (hash-ref method-mindex m-name))
                     (list (datum->syntax #'name m-name)
                           (mindex-index mix)
                           (let ([r (hash-ref method-results m-name #f)])
                             (and (pair? r) (car r)))))]
                  [((private-method-name private-method-id private-method-id/property private-method-result-id) ...)
                   (for/list ([m-name (in-list (sort (hash-keys method-private)
                                                     symbol<?))])
                     (define id/property (hash-ref method-private m-name))
                     (list (datum->syntax #'name m-name)
                           (if (pair? id/property) (car id/property) id/property)
                           id/property
                           (let ([r (hash-ref method-results m-name #f)])
                             (and (pair? r) (car r)))))])
      (list
       #`(define-values #,(for/list ([added (in-list added-methods)]
                                     #:when (not (eq? 'abstract (added-method-mode added))))
                            (added-method-rhs-id added))
           (let ()
             (define-syntax field-name (make-field-syntax (quote-syntax field-name)
                                                          (quote-syntax name-field)
                                                          (quote-syntax maybe-set-name-field!)))
             ...
             (define-syntax method-name (make-method-syntax (quote-syntax method-name)
                                                            (quote-syntax method-index/id)
                                                            (quote-syntax method-result-id)))
             ...
             (define-syntax private-method-name (make-method-syntax (quote-syntax private-method-name)
                                                                    (quote-syntax private-method-id)
                                                                    (quote-syntax private-method-result-id)))
             ...
             (define-syntax new-private-tables (cons (cons (quote-syntax name)
                                                           (hasheq (~@ 'private-method-name
                                                                       (quote-syntax private-method-id/property))
                                                                   ...
                                                                   (~@ 'private-field-name
                                                                       private-field-desc)
                                                                   ...))
                                                     (get-private-tables)))
             #,@(for/list ([added (in-list added-methods)]
                           #:when (eq? 'abstract (added-method-mode added))
                           #:when (syntax-e (added-method-rhs added)))
                  #`(void (rhombus-expression #,(added-method-rhs added))))
             (values
              #,@(for/list ([added (in-list added-methods)]
                            #:when (not (eq? 'abstract (added-method-mode added))))
                   (define r (hash-ref method-results (syntax-e (added-method-id added)) #f))
                   #`(let ([#,(added-method-id added) (method-block #,(added-method-rhs added)
                                                                    name name-instance name?
                                                                    #,(and r (car r)) #,(added-method-id added)
                                                                    new-private-tables
                                                                    [super-name ...])])
                       #,(added-method-id added))))))))))

(define-syntax (method-block stx)
  (syntax-parse stx
    #:datum-literals (block)
    [(_ (block expr)
        name name-instance name?
        result-id method-name
        private-tables-id
        super-names)
     #:do [(define result-pred
             (cond
               [(not (syntax-e #'result-id)) #f]
               [else (method-result-predicate-expr (syntax-local-method-result #'result-id))]))]
     #:with (~var e (:entry-point (entry-point-adjustments
                                   (list #'this-obj)
                                   (lambda (stx)
                                     #`(syntax-parameterize ([this-id (quote-syntax (this-obj name-instance . super-names))]
                                                             [private-tables (quote-syntax private-tables-id)])
                                         ;; This check might be redundant, depending on how the method was called:
                                         (unless (name? this-obj) (raise-not-an-instance 'name this-obj))
                                         #,(let ([body #`(let ()
                                                           #,stx)])
                                             (if result-pred
                                                 #`(let ([result #,body])
                                                     (unless (#,result-pred result)
                                                       (raise-result-failure 'method-name result))
                                                     result)
                                                 body))))
                                   #t)))
     #'expr
     #'e.parsed]))

