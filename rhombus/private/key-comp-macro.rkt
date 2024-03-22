#lang racket
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest/name-parse)
         "space-provide.rkt"
         "definition.rkt"
         "mutability.rkt"
         "key-comp.rkt"
         "parens.rkt"
         "to-list.rkt"
         (submod "map.rkt" for-key-comp-macro)
         (submod "set.rkt" for-key-comp-macro)
         "realm.rkt"
         "parse.rkt"
         "key-comp-property.rkt"
         "version-case.rkt")

(meta-if-version-at-least
 "8.12.0.15"
 (require (only-in racket/unsafe/ops unsafe-impersonate-hash))
 (define (unsafe-impersonate-hash . _)
   (error "`key_comp.def` requires a newer version of Racket")))

(define+provide-space key_comp rhombus/key_comp
  #:fields
  (def))

(define-defn-syntax def
  (definition-transformer
    (lambda (stx)
      (syntax-parse stx
        #:datum-literals (group)
        [(_ (_::quotes (group name::name))
            (body-tag::block
             (~and
              (~seq (group kw clause-block) ...)
              (~seq
               (~alt (~optional (group #:equals
                                       (equals-tag::block
                                        equals-body ...)))
                     (~optional (group #:hash_code
                                       (hash-code-tag::block
                                        hash-code-body ...))))
               ...))))
         (unless (attribute equals-tag)
           (raise-syntax-error #f "missing a `~equals` clause" stx))
         (unless (attribute hash-code-tag)
           (raise-syntax-error #f "missing an `~hash_code` clause" stx))
         (with-syntax ([x-map-pair-build (datum->syntax #'here (string->symbol
                                                                (format "Map.by(~s)" (syntax-e #'name.name))))]
                       [x-mutable-map-build (datum->syntax #'here (string->symbol
                                                                   (format "MutableMap.by(~s)" (syntax-e #'name.name))))]
                       [x-set-build (datum->syntax #'here (string->symbol
                                                           (format "Set.by(~s)" (syntax-e #'name.name))))]
                       [x-mutable-set-build (datum->syntax #'here (string->symbol
                                                                   (format "MutableSet.by(~s)" (syntax-e #'name.name))))])
           #`((define-values (x-equals? x-hash-code)
                (hash-procedures (~@ kw (rhombus-body-expression clause-block)) ...))
              ;; keys are wrapped in this struct, which lets use own own
              ;; hash function for the keys
              (struct x (v)
                #:property prop:equal+hash (list (lambda (a b recur mode)
                                                   (x-equals? (x-v a) (x-v b) recur))
                                                 (lambda (a recur mode)
                                                   (x-hash-code (x-v a) recur))))
              (define x-custom-map (custom-map 'name.name
                                               (lambda (ht)
                                                 (mutable-copy! (wrap (make-hash)) ht))
                                               (lambda (ht)
                                                 (if (immutable-hash? ht)
                                                     ht
                                                     (build-map 'hash-snapshot empty-x-map (hash-map ht list))))))
              (define (x-map? v) (eq? (custom-map-ref v #f) x-custom-map))
              (define (wrap ht)
                (unsafe-impersonate-hash ht
                                         ;; ref
                                         (lambda (ht key)
                                           (values (x key)
                                                   (lambda (ht key val) val)))
                                         ;; set
                                         (lambda (ht key val)
                                           (values (x key) val))
                                         ;; remove
                                         (lambda (ht key)
                                           (x key))
                                         ;; key
                                         (lambda (ht key)
                                           (x-v key))
                                         ;; clear
                                         (lambda (ht) (void))
                                         prop:custom-map x-custom-map))
              (define empty-x-map (wrap #hash()))
              (define (x-map-build . args)
                (build-map 'x-map-build empty-x-map (args->pairs 'x-map-build args)))
              (define (x-map-pair-build . pairs)
                (build-map 'x-map-build empty-x-map (to-list 'x-map-build pairs)))
              (define (list->x-map pairs)
                (build-map 'list->x-map empty-x-map (to-pairs (to-list 'list->x-map pairs))))
              (define (mutable-x-map? v)
                (and (mutable-hash? v) (x-map? v)))
              (define (x-mutable-map-build args)
                (define ht (wrap (make-hash)))
                (build-mutable-map 'x-mutable-map-build ht (to-list 'x-mutable-map-build args)))
              (define (immutable-x-set? v)
                (and (set? v) (immutable-hash? (set-ht v)) (x-map? (set-ht v))))
              (define (x-set-build . args)
                (list->x-set args))
              (define (list->x-set args)
                (x-map-set-build args empty-x-map))
              (define (mutable-x-set? v)
                (and (set? v) (mutable-hash? (set-ht v)) (x-map? (set-ht v))))
              (define (x-mutable-set-build . args)
                (define ht (wrap (make-hash)))
                (build-mutable-set 'x-mutable-set-build ht args))
              (define-key-comp-syntax name.name
                (key-comp 'name.name #'x-map?
                          #'x-map-build #'x-map-pair-build #'list->x-map
                          #'mutable-x-map? #'x-mutable-map-build
                          #'empty-x-map
                          #'immutable-x-set?
                          #'x-set-build #'x-set-build #'list->x-set
                          #'mutable-x-set? #'x-mutable-set-build))))]))))

(define (hash-procedures #:equals equals #:hash_code hash_code)
  (unless (and (procedure? equals) (procedure-arity-includes? equals 3))
    (raise-argument-error* 'key_comp.def rhombus-realm "Function.of_arity(3)" equals))
  (unless (and (procedure? hash_code) (procedure-arity-includes? hash_code 2))
    (raise-argument-error* 'key_comp.def rhombus-realm "Function.of_arity(2)" hash_code))
  (values equals hash_code))

(define (x-map-set-build elems ht)
  (set
   (for/fold ([ht ht]) ([e (in-list elems)])
     (hash-set ht e #t))))

(define (build-mutable-map who ht args)
  (for ([p (in-list (args->pairs who args))])
    (hash-set! ht (car p) (cadr p)))
  ht)

(define (mutable-copy! ht ht-in)
  (for ([(k v) (in-hash ht-in)])
    (hash-set! ht k v))
  ht)

(define (build-mutable-set who ht args)
  (for ([e (in-list args)])
    (hash-set! ht e #t))
  (set ht))

(define (args->pairs who orig-args)
  (let loop ([args orig-args])
    (cond
      [(null? args) null]
      [(null? (cdr args))
       (raise-arguments-error who "expected an even number of arguments")]
      [else (cons (list (car args) (cadr args)) (loop (cddr args)))])))

(define (to-pairs l)
  (for/list ([p (in-list l)])
    (list (car p) (cdr p))))
