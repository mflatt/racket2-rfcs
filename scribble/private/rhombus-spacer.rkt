#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     "typeset_meta.rhm"
                     "property.rkt"
                     rhombus/private/pack)
         (only-in rhombus
                  [= rhombus-=]
                  [/ rhombus-/]
                  [file rhombus-file]
                  [lib rhombus-lib]
                  [values rhombus-values]))

(provide (for-space rhombus/scribble/typeset
                    ::
                    :~
                    |'|
                    |#'|
                    fun
                    constructor
                    val
                    def
                    match
                    for
                    import
                    class
                    interface
                    extends
                    implements))

(define-syntax (define-spacer stx)
  (syntax-parse stx
    [(_ id:identifier rhs)
     #`(define-syntax #,(in_space #'id)
         rhs)]))

(define-for-syntax (spacer proc)
  (make_Spacer
   (lambda (head tail escape)
     (define-values (new-head new-unpacked-tail)
       (proc head (unpack-tail tail #f #f) escape))
     (values new-head
             (pack-tail new-unpacked-tail)))))

(define-for-syntax (escape? form escape)
  (if (identifier? escape)
      (and (identifier? form)
           (free-identifier=? form escape))
      (syntax-parse form
        #:datum-literals (op)
        [(op id) (free-identifier=? #'id
                                    (cadr (syntax->list escape)))]
        [_ #f])))

(define-for-syntax annote-spacer
  (spacer
   (lambda (head tail escape)
     (values head
             (let loop ([tail tail])
               (syntax-parse tail
                 #:datum-literals (group op =)
                 [((op =) . more) tail] ; in function arguments?
                 [(a . more)
                  #:when (not (escape? #'a escape))
                  #`(#,(term-identifiers-syntax-property #'a 'typeset-space-name 'annot)
                     . #,(loop #'more))]
                 [_ tail]))))))

(define-spacer :: annote-spacer)
(define-spacer :~ annote-spacer)

(define-spacer |#'|
  (spacer
   (lambda (head tail escape)
     (values head
             (syntax-parse tail
               [(a:identifier . more)
                #:when (not (escape? #'a escape))
                #`(#,(term-identifiers-syntax-property #'a 'typeset-space-name 'value)
                   . more)]
               [_ tail])))))

(define-spacer |'|
  (spacer
   (lambda (head tail escape)
     (values head
             (syntax-parse tail
               #:datum-literals (parens)
               [(((~and tag parens) g) . more)
                #`((tag
                    #,(group-identifiers-syntax-property #'g
                                                         (lambda (id)
                                                           (if (eq? (syntax-e id) '$)
                                                               id
                                                               (syntax-property id 'typeset-space-name #f)))
                                                         #f))
                   . more)]
               [_ tail])))))

(define-spacer fun
  (spacer
   (lambda (head tail escape)
     (fun-spacer head tail escape))))

(define-spacer constructor
  (spacer
   (lambda (head tail escape)
     (fun-spacer head tail escape))))

(define-spacer val
  (spacer
   (lambda (head tail escape)
     (val-spacer head tail escape))))

(define-for-syntax (arg-spacer stx)
  (syntax-parse stx
    #:datum-literals (group op = block)
    [((~and tag group) kw:keyword ((~and b-tag block) g))
     #`(tag kw (b-tag #,(arg-spacer #'g)))]
    [((~and tag group) a ... (~and eq (op =)) e ...)
     #`(tag #,@(for/list ([a (in-list (syntax->list #'(a ...)))])
                 (term-identifiers-syntax-property a 'typeset-space-name 'bind))
            eq
            e ...)]
    [_
     (group-identifiers-syntax-property stx 'typeset-space-name 'bind)]))

(define-for-syntax (fun-spacer head tail escape)
  (define (post-spacer stx)
    (syntax-parse stx
      #:datum-literals (op)
      [((~and ann (op _)) . more)
       (cons (term-identifiers-syntax-property #'ann 'typeset-space-name 'bind)
             #'more)]
      [else stx]))
  (define new-tail (syntax-parse tail
                     #:datum-literals (parens group op)
                     [(esc form ((~and tag parens) arg ...) . more)
                      #:when (escape? #'esc escape)
                      #`(esc form
                             #,(cons #'tag (map arg-spacer (syntax->list #'(arg ...))))
                             . #,(post-spacer #'more))]
                     [(id ((~and tag parens) arg ...) . more)
                      #`(id
                         #,(cons #'tag (map arg-spacer (syntax->list #'(arg ...))))
                         . #,(post-spacer #'more))]
                     [(((~and tag parens) arg ...) . more)
                      #`(#,(cons #'tag (map arg-spacer (syntax->list #'(arg ...))))
                         . #,(post-spacer #'more))]
                     [_ tail]))
  (values head new-tail))

(define-for-syntax (val-spacer head tail escape)
  (define new-tail (syntax-parse tail
                     #:datum-literals (group block)
                     [(b ... (~and bl (block . _)))
                      #`(#,@(for/list ([b (in-list (syntax->list #'(b ...)))])
                              (term-identifiers-syntax-property b 'typeset-space-name 'bind))
                         bl)]
                     [_ tail]))
  (values head new-tail))

(define-spacer def
  (spacer
   (lambda (head tail escape)
     (syntax-parse tail
       #:datum-literals (group op)
       [(esc ((~and tag parens) arg ...) . more)
        #:when (escape? #'esc escape)
        (values head tail)]
       [(id ((~and tag parens) arg ...) . more)
        #:when (and (identifier? #'id)
                    (not (free-identifier=? #'id #'rhombus-values)))
        (fun-spacer head tail escape)]
       [else
        (val-spacer head tail escape)]))))

(define-spacer match
  (spacer
   (lambda (head tail escape)
     (define (binding-spacer stx)
       (term-identifiers-syntax-property stx 'typeset-space-name 'bind))
     (define new-tail (syntax-parse tail
                        #:datum-literals (alts group)
                        [(expr ... ((~and tag alts) b ...))
                         #`(expr ...
                                 (tag
                                  #,@(for/list ([b (in-list (syntax->list #'(b ...)))])
                                       (syntax-parse b
                                         #:datum-literals (block)
                                         [((~and tag block) ((~and g-tag group) form ... (~and b (block . _))))
                                          #`(tag
                                             (g-tag #,@(map binding-spacer (syntax->list #'(form ...)))
                                                    b))]
                                         [_ b]))))]
                        [_ tail]))
     (values head new-tail))))

(define-spacer for
  (spacer
   (lambda (head tail escape)
     (define new-tail (syntax-parse tail
                        #:datum-literals (group block)
                        [(((~and block-tag block) body ... ((~and group-tag group) (~and into #:into) reducer ...)))
                         #`((block-tag
                             #,@(map for-body-spacer (syntax->list #'(body ...)))
                             (group-tag into #,(for/list ([reducer (in-list (syntax->list #'(reducer ...)))])
                                                 (term-identifiers-syntax-property reducer 'typeset-space-name 'reducer)))))]
                        [(reducer ... ((~and block-tag block) body ...))
                         #`(#,@(for/list ([reducer (in-list (syntax->list #'(reducer ...)))])
                                 (term-identifiers-syntax-property reducer 'typeset-space-name 'reducer))
                            (block-tag
                             #,@(map for-body-spacer (syntax->list #'(body ...)))))]
                        [_
                         tail]))
     (values head new-tail))))

(define-for-syntax (for-body-spacer body)
  (syntax-parse body
    #:datum-literals (each keep_when skip_when break_when final_when)
    [(group (~and id (~or each keep_when skip_when break_when final_when)) . args)
     #`(group #,(term-identifiers-syntax-property #'id 'typeset-space-name 'for_clause) . args)]
    [_
     body]))

(define-spacer import
  (spacer
   (lambda (head tail escape)
     (define new-tail (syntax-parse tail
                        #:datum-literals (group block)
                        [(((~and block-tag block) body ...))
                         #`((block-tag
                             #,@(map import-clause-spacer (syntax->list #'(body ...)))))]
                        [(g)
                         #`(#,(import-clause-spacer #'g))]
                        [_
                         tail]))
     (values head new-tail))))

(define-for-syntax (import-clause-spacer c)
  (define (hide stx)
    (term-identifiers-syntax-property stx 'typeset-space-name 'hide))
  (define (as-mod stx)
    (term-identifiers-syntax-property stx 'typeset-space-name 'impo))
  (syntax-parse c
    #:datum-literals (group)
    [((~and tag group) c ...)
     #`(tag #,@(let loop ([cs #'(c ...)])
                 (define (free=? a b space)
                   (free-identifier=? a ((make-interned-syntax-introducer space) b)))
                 (syntax-parse cs
                   #:datum-literals (group op |.| open as)
                   [(id:identifier) (list (hide #'id))]
                   [(mp (~and mod open)) (list (hide #'mp) (as-mod #'mod))]
                   [(mp (~and mod as) id:identifier) (list (hide #'mp) (as-mod #'mod) (hide #'id))]
                   [(id:identifier (~and slash (op use-/)) . cs)
                    #:when (or (free=? #'use-/ #'rhombus-/ 'rhombus/impo)
                               (free=? #'use-/ #'rhombus-/ 'rhombus/modpath))
                    (list (hide #'id)
                          (as-mod #'slash)
                          (loop #'cs))]
                   [(id:identifier (~and dot (op |.|)) . cs)
                    (list* (hide #'id)
                           (as-mod #'dot)
                           (loop #'cs))]
                   [((~and dot (op |.|)) . cs)
                    (list* (as-mod #'dot)
                           (loop #'cs))]
                   [(id:identifier str . cs)
                    #:when (or (free=? #'id #'rhombus-file 'rhombus/impo)
                               (free=? #'id #'rhombus-file 'rhombus/modpath))
                    (list* (as-mod #'id)
                           #'str
                           (loop #'cs))]
                   [(id:identifier str . cs)
                    #:when (or (free=? #'id #'rhombus-lib 'rhombus/impo)
                               (free=? #'id #'rhombus-lib 'rhombus/modpath))
                    (list* (as-mod #'id)
                           #'str
                           (loop #'cs))]
                   [else cs])))]))

(define-spacer class
  (spacer
   (lambda (head tail escape)
     (define new-tail (syntax-parse tail
                        #:datum-literals (group block parens)
                        [(name ((~and parens-tag parens) arg ...) ((~and block-tag block) body ...))
                         #`(name (parens-tag #,@(map arg-spacer (syntax->list #'(arg ...))))
                            (block-tag
                             #,@(map (class-clause-spacer 'class_clause) (syntax->list #'(body ...)))))]
                        [(name ((~and parens-tag parens) arg ...) ((~and block-tag block) body ...))
                         #`(name (parens-tag #,@(map arg-spacer (syntax->list #'(arg ...)))))]
                        [_
                         tail]))
     (values head new-tail))))

(define-spacer interface
  (spacer
   (lambda (head tail escape)
     (define new-tail (syntax-parse tail
                        #:datum-literals (group block parens)
                        [(name ((~and block-tag block) body ...))
                         #`(name
                            (block-tag
                             #,@(map (class-clause-spacer 'intf_clause) (syntax->list #'(body ...)))))]
                        [_
                         tail]))
     (values head new-tail))))

(define-for-syntax ((class-clause-spacer space) stx)
  (syntax-parse stx
    #:datum-literals (group)
    [((~and group-tag group) form:identifier . rest)
     #`(group-tag #,(term-identifiers-syntax-property #'form 'typeset-space-name space)
                  . rest)]
    [_ stx]))

(define-spacer extends
  (spacer
   (lambda (head tail escape)
     (extends-spacer head tail escape))))

(define-spacer implements
  (spacer
   (lambda (head tail escape)
     (extends-spacer head tail escape))))

(define-for-syntax (extends-spacer head tail escape)
  (values head
          (for/list ([e (syntax->list tail)])
            (term-identifiers-syntax-property e 'typeset-space-name 'class))))
