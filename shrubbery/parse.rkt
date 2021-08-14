#lang racket/base
(require racket/pretty
         "lex.rkt"
         "srcloc.rkt")

(provide parse-all)

;; Parsing state at the group level:
(struct state (line            ; current group's line and last consumed token's line
               column          ; group's column; below ends group, above starts indented
               paren-immed?    ; immediately in `()` or `[]`?
               bar-closes?     ; does `|` end a group?
               delta))         ; column delta created by `\`, applied to `line` continuation

(define (make-state #:line line
                    #:column column
                    #:paren-immed? [paren-immed? #f]
                    #:bar-closes? [bar-closes? #f]
                    #:delta delta)
  (state line
         column
         paren-immed?
         bar-closes?
         delta))

;; Parsing state for group sequences: top level, in opener-closer, or after `:`
(struct group-state (closer         ; expected closer: a string, EOF, or column
                     paren-immed?   ; immediately in `()` or `[]`?
                     column         ; not #f => required indentation check checking
                     check-column?  ; #f => allow any sufficiently large (based on closer) indentation
                     bar-closes?    ; does `|` end the sequence of groups?
                     bar-ok?        ; ok to start with a bar group?
                     comma-time?    ; allow and expect a comma next
                     last-line      ; most recently consumed line
                     delta          ; column delta created by `\`, applies to `last-line` continuation
                     commenting     ; pending group-level `#//` token; exclusive with `tail-commenting`
                     tail-commenting)) ; pending group-level `#//` at end (so far)

(define (make-group-state #:closer closer
                          #:paren-immed? [paren-immed? #f]
                          #:column column
                          #:check-column? [check-column? #t]
                          #:bar-closes? [bar-closes? #f]
                          #:bar-ok? [bar-ok? #f]
                          #:last-line last-line
                          #:delta delta
                          #:commenting [commenting #f])
  (group-state closer
               paren-immed?
               column
               check-column?
               bar-closes?
               bar-ok?
               #f
               last-line
               delta
               #f
               commenting))

(define closer-column? number?)

(define closer-expected? pair?)
(define (closer-expected closer) (if (pair? closer) (car closer) closer))
(define (closer-expected-opener closer) (and (pair? closer) (cdr closer)))
(define (make-closer-expected str tok) (cons str tok))

;; ----------------------------------------

;; In the parsed representation of a shrubbery, source locations are
;; not associated with sequences tagged `group` or `top`. For terms
;; tagged with `parens`, `braces`, `block`, `alts`, and `op`, the same
;; source location is associated with the tag and the parentheses that
;; group the tag with its members, and that location spans the content
;; and any delimiters used to form it (such as parentheses or a `:`
;; that starts a block).

;; Parse all groups in a stream
(define (parse-top-groups l)
  (define-values (gs rest-l end-line end-delta end-t tail-commenting)
    (parse-groups l (make-group-state #:closer eof
                                      #:column #f
                                      #:check-column? #f
                                      #:last-line -1
                                      #:delta 0)))
  (when tail-commenting (fail-no-comment-group tail-commenting))
  (unless (null? rest-l)
    (error "had leftover items" rest-l))
  (lists->syntax (cons 'top (bars-insert-alts gs))))

;; Parse a sequence of groups (top level, in opener-closer, or after `:`)
;;   consuming the closer in the case of opener-closer context.
;; Returns: the list of groups
;;          remaining tokens after a closer
;;          line of last consumed (possibly closer)
;;          delta of last consumed
;;          last token consumed (if a closer)
;;          pending group-comment token from end
(define (parse-groups l sg)
  (define (check-no-commenting #:tail-ok? [tail-ok? #f])
    (define commenting (or (group-state-commenting sg)
                           (and (not tail-ok?) (group-state-tail-commenting sg))))
    (when commenting
      (fail-no-comment-group commenting)))
  (define (done end-t)
    (check-no-commenting #:tail-ok? #t)
    (values null l (group-state-last-line sg) (group-state-delta sg) end-t (group-state-tail-commenting sg)))
  (define (check-column t column)
    (when (group-state-check-column? sg)
      (unless (= column (group-state-column sg))
        (fail t "wrong indentation"))))
  (define closer (group-state-closer sg))
  (cond
    [(null? l)
     ;; Out of tokens
     (when (string? (closer-expected closer))
       (fail (closer-expected-opener closer) (format "expected ~s" (closer-expected closer))))
     (done #f)]
    [else
     (define t (car l))
     (define column (+ (token-column t) (group-state-delta sg)))
     (cond
       [(eq? (token-name t) 'group-comment)
        ;; column doesn't matter
        (define-values (rest-l last-line delta) (next-of (cdr l) (token-line t) (group-state-delta sg)))
        (cond
          [(and ((token-line t) . > . (group-state-last-line sg))
                (next-line? rest-l last-line))
           ;; structure comment is on its own line, so it comments out next group
           (check-no-commenting)
           (parse-groups rest-l (struct-copy group-state sg
                                             [last-line last-line]
                                             [delta delta]
                                             [tail-commenting t]))]
          [else
           (fail t "misplaced group comment!")])]
       [(and (closer-column? closer)
             (column . < . closer))
        ;; Next token is less indented than this group sequence
        (done #f)]
       [else
        ;; Dispatch on token
        (case (token-name t)
          [(closer)
           (cond
             [(closer-column? closer)
              (done #f)]
             [else
              (unless (equal? (closer-expected closer) (token-e t))
                (fail t (format "expected ~s; closing at ~a" (closer-expected closer) (token-value t))))
              (if (eof-object? (closer-expected closer))
                  ;; continue after extra closer:
                  (parse-groups (cdr l) (struct-copy group-state sg
                                                     [last-line (token-line t)]))
                  ;; stop at closer
                  (begin
                    (check-no-commenting)
                    (values null (cdr l) (token-line t) (group-state-delta sg) t #f)))])]
          [(whitespace comment continue-operator)
           (define-values (next-l last-line delta) (next-of l
                                                            (group-state-last-line sg)
                                                            (group-state-delta sg)))
           (parse-groups next-l (struct-copy group-state sg
                                             [last-line last-line]
                                             [delta delta]))]
          [(comma-operator)
           (cond
             [(closer-column? (group-state-closer sg))
              (done #f)]
             [else
              (unless (and (group-state-paren-immed? sg)
                           (group-state-comma-time? sg))
                (fail t (format "misplaced comma~a"
                                (if (group-state-paren-immed? sg)
                                    ""
                                    " (not immdiately within parentheses or brackets)"))))
              (define-values (rest-l last-line delta) (next-of (cdr l) (token-line t) (group-state-delta sg)))
              ;; In top level or immediately in opener-closer: 
              (parse-groups (cdr l) (struct-copy group-state sg
                                                 [check-column? (next-line? rest-l last-line)]
                                                 [last-line last-line]
                                                 [comma-time? #f]
                                                 [delta delta]))])]
          [(semicolon-operator)
           (when (group-state-paren-immed? sg)
             (fail t (format "misplaced semicolon (~a)"
                             "immdiately within parentheses or brackets")))
           (check-column t column)
           (define-values (rest-l last-line delta) (next-of (cdr l) (token-line t) (group-state-delta sg)))
           (parse-groups rest-l (struct-copy group-state sg
                                             [check-column? (next-line? rest-l last-line)]
                                             [column (or (group-state-column sg) column)]
                                             [last-line last-line]
                                             [delta delta]
                                             [commenting (group-state-tail-commenting sg)]
                                             [tail-commenting #f]))]
          [else
           (when (group-state-comma-time? sg)
             (fail t (format "missing comma before new group (~a)"
                             "within parentheses or braces")))
           (case (token-name t)
             [(bar-operator)
              (cond
                [(group-state-bar-closes? sg)
                 (done #f)]
                [(group-state-bar-ok? sg)
                 ;; Bar at the start of a group
                 (define line (token-line t))
                 (define same-line? (or (not (group-state-last-line sg))
                                        (= line (group-state-last-line sg))))
                 (when (group-state-check-column? sg)
                   (unless (or same-line?
                               (= column (group-state-column sg)))
                     (fail t "wrong indentation")))
                 (define-values (g rest-l group-end-line group-end-delta block-tail-commenting)
                   (parse-block t l
                                #:closer (column-next column)
                                #:bar-closes? #t
                                #:delta (group-state-delta sg)))
                 (define commenting (or (group-state-commenting sg)
                                        (group-state-tail-commenting sg)))
                 (define-values (gs rest-rest-l end-line end-delta end-t tail-commenting)
                   (parse-groups rest-l (struct-copy group-state sg
                                                     [column (if same-line?
                                                                 (group-state-column sg)
                                                                 column)]
                                                     [check-column? #t]
                                                     [last-line group-end-line]
                                                     [delta group-end-delta]
                                                     [comma-time? (group-state-paren-immed? sg)]
                                                     [commenting #f]
                                                     [tail-commenting block-tail-commenting])))
                 (values (if commenting
                             gs
                             (cons (list 'group
                                         (add-span-srcloc
                                          t end-t
                                          (cons 'bar g)))
                                   gs))
                         rest-rest-l
                         end-line
                         end-delta
                         end-t
                         tail-commenting)]
                [else
                 (fail t "misplaced `|`")])]
             [else
              ;; Parse one group, then recur to continue the sequence:
              (check-column t column)
              (define line (token-line t))
              (define-values (g rest-l group-end-line group-delta group-tail-commenting)
                (parse-group l (make-state #:paren-immed? (group-state-paren-immed? sg)
                                           #:line line
                                           #:column column
                                           #:bar-closes? (group-state-bar-closes? sg)
                                           #:delta (group-state-delta sg))))
              (define commenting (or (group-state-commenting sg)
                                     (group-state-tail-commenting sg)))
              (define-values (gs rest-rest-l end-line end-delta end-t tail-commenting)
                (parse-groups rest-l (struct-copy group-state sg
                                                  [column (or (group-state-column sg) column)]
                                                  [check-column? (next-line? rest-l group-end-line)]
                                                  [last-line group-end-line]
                                                  [comma-time? (group-state-paren-immed? sg)]
                                                  [delta group-delta]
                                                  [commenting #f]
                                                  [tail-commenting group-tail-commenting])))
              (values (if (or commenting
                              (null? g)) ; can happen due to a term comment
                          gs
                          (cons (cons 'group g)
                                gs))
                      rest-rest-l
                      end-line
                      end-delta
                      end-t
                      tail-commenting)])])])]))

;; Parse one group.
;; Returns: the list of items in the group
;;          remaining tokens after group
;;          line of last consumed
;;          delta at last consumed
;;          pending group-comment token from end
(define (parse-group l s)
  (define (done)
    (values null l (state-line s) (state-delta s) #f))
  (cond
    [(null? l) (done)]
    [else
     (define t (car l))
     (define line (token-line t))
     ;; Consume a token
     (define (keep delta)
       (define-values (g rest-l end-line end-delta tail-commenting)
         (parse-group (cdr l) (struct-copy state s
                                           [line line]
                                           [delta delta])))
       (values (cons (token-value t) g) rest-l end-line end-delta tail-commenting))
     ;; Dispatch
     (cond
       [(line . > . (state-line s))
        ;; new line
        (case (token-name t)
          [(whitespace comment)
           (parse-group (cdr l) (struct-copy state s
                                             [line line]
                                             [delta 0]))]
          [else
           ;; consume any structure comments that are on their own line:
           (define-values (group-commenting use-t use-l last-line delta)
             (get-own-line-group-comment t l (state-line s) (state-delta s)))
           (define column (token-column use-t))
           (cond
             [(column . > . (state-column s))
              ;; More indented forms a nested block, but we require
              ;; `:` or `|` to indicate that it's ok to start an
              ;; indented block
              (fail use-t "wrong indentation (or missing `:` on previous line)")]
             [(and (state-paren-immed? s)
                   (eq? 'operator (token-name use-t)))
              ;; Treat an non-indented leading operator as a continuation of the group
              (when group-commenting
                (fail-no-comment-group group-commenting))
              (keep 0)]
             [else
              ;; using `done` here means that we leave any group comments in place;
              ;; not consuming inspected tokens is normally worrisome, but we'll parse
              ;; them at most one more time
              (done)])])]
       [else
        ;; Not a new line
        (case (token-name t)
          [(closer comma-operator semicolon-operator)
           (done)]
          [(identifier number literal operator)
           (keep (state-delta s))]
          [(block-operator)
           (parse-block t l
                        #:closer (column-half-next (state-column s))
                        #:delta (state-delta s))]
          [(bar-operator)
           (cond
             [(state-bar-closes? s)
              (done)]
             [else
              (fail t "misplaced `|` or missing `:` before")])]
          [(opener)
           (define-values (closer tag paren-immed?)
             (case (token-e t)
               [("(") (values ")" 'parens #t)]
               [("{") (values "}" 'block #f)]
               [("[") (values "]" 'brackets #t)]
               [else (error "unknown opener" t)]))
           (define-values (group-commenting next-l last-line delta) (next-of/commenting (cdr l) line (state-delta s)))
           (define sub-column
             (if (pair? next-l)
                 (+ (token-column (car next-l)) (state-delta s))
                 (column-next (+ (token-column t) (state-delta s)))))
           (define-values (gs rest-l close-line close-delta end-t never-tail-commenting)
             (parse-groups next-l (make-group-state #:closer (make-closer-expected closer t)
                                                    #:paren-immed? paren-immed?
                                                    #:bar-ok? (not paren-immed?)
                                                    #:column sub-column
                                                    #:last-line last-line
                                                    #:delta delta
                                                    #:commenting group-commenting)))
           (define-values (g rest-rest-l end-line end-delta tail-commenting)
             (parse-group rest-l (struct-copy state s
                                              [line close-line]
                                              [delta close-delta])))
           (values (cons (add-span-srcloc
                          t end-t
                          (if (eq? tag 'block)
                              (tag-as-block gs)
                              (cons tag (bars-insert-alts gs))))
                         g)
                   rest-rest-l
                   end-line
                   end-delta
                   tail-commenting)]
          [(whitespace comment continue-operator)
           (define-values (next-l line delta) (next-of l (state-line s) (state-delta s)))
           (parse-group next-l (struct-copy state s
                                            [line line]
                                            [delta delta]))]
          [(group-comment)
           (fail t "misplaced group comment")]
          [else
           (error "unexpected" t)])])]))

(define (parse-block block-t l
                     #:closer closer
                     #:bar-closes? [bar-closes? #f]
                     #:delta in-delta)
  (define t (car l))
  (define line (token-line t))
  (define-values (group-commenting next-l last-line delta) (next-of/commenting (cdr l) line in-delta))
  (cond
    [(pair? next-l)
     (define next-t (car next-l))
     (define-values (indent-gs rest-l end-line end-delta end-t tail-commenting)
       (parse-groups next-l
                     (make-group-state #:closer closer
                                       #:column (+ (token-column next-t) delta)
                                       #:last-line last-line
                                       #:bar-closes? bar-closes?
                                       #:bar-ok? #t
                                       #:delta delta
                                       #:commenting group-commenting)))
     (values (list (add-span-srcloc
                    t end-t
                    (tag-as-block indent-gs)))
             rest-l
             end-line
             end-delta
             tail-commenting)]
    [else
     (values (list (add-span-srcloc
                    block-t #f
                    (tag-as-block null)))
             next-l
             line
             delta
             group-commenting)]))

(define (tag-as-block gs)
  (cond
    [(and (pair? gs)
          ;; really only need to check the first one:
          (for/and ([g (in-list gs)])
            (and (pair? g)
                 (eq? 'group (car g))
                 (pair? (cdr g))
                 (null? (cddr g))
                 (let ([b (cadr g)])
                   (and (pair? b)
                        (tag? 'bar (car b))
                        ;; the rest should always be true:
                        (pair? (cdr b))
                        (null? (cddr b))
                        (pair? (cadr b))
                        (tag? 'block (caadr b)))))))
     (cons 'alts (for/list ([g (in-list gs)])
                   (let ([b (cadr g)])
                     (cadr b))))]
    [else (cons 'block gs)]))

(define (bars-insert-alts gs)
  (cond
    [(and (pair? gs)
          ;; same check is in `tag-as-block
          (let ([g (car gs)])
            (and (pair? g)
                 (eq? 'group (car g))
                 (pair? (cdr g))
                 (null? (cddr g))
                 (let ([b (cadr g)])
                   (and (pair? b)
                        (tag? 'bar (car b))
                        (car b))))))
     => (lambda (bar-tag)
          (list (list 'group
                      (add-span-srcloc
                       bar-tag #f
                       (tag-as-block gs)))))]
    [else gs]))

(define (tag? sym e)
  (or (eq? sym e)
      (and (syntax? e)
           (eq? sym (syntax-e e)))))

(define (add-span-srcloc start-t end-t l)
  (cond
    [(not start-t) l]
    [else
     (define (add-srcloc l loc)
       (cons (datum->syntax #f (car l) loc stx-for-original-property)
             (cdr l)))
     (define last-t/e (or end-t
                          ;; when `end-t` is false, we go looking for the
                          ;; end in `l`; this search walks down the end
                          ;; of `l`, and it may recur into the last element,
                          ;; but it should go only a couple of levels that way,
                          ;; since non-`group` tags have spanning locations
                          ;; gather from their content
                          (let loop ([e l])
                            (cond
                              [(syntax? e) e]
                              [(not (pair? e)) #f]
                              [(null? (cdr e))
                               (define a (car e))
                               (if (and (pair? a)
                                        (syntax? (car a)))
                                   ;; found a tag like `block`
                                   (car a)
                                   (loop a))]
                              [else (loop (cdr e))]))))
     (define s-loc (if (syntax? start-t)
                       (syntax-srcloc start-t)
                       (token-srcloc start-t)))
     (define e-loc (and last-t/e
                        (if (syntax? last-t/e)
                            (syntax-srcloc last-t/e)
                            (token-srcloc last-t/e))))
     (define s-position (srcloc-position s-loc))
     (add-srcloc l (srcloc (srcloc-source s-loc)
                           (srcloc-line s-loc)
                           (srcloc-column s-loc)
                           s-position
                           (if e-loc
                               (let ([s s-position]
                                     [e (srcloc-position e-loc)]
                                     [sp (srcloc-span e-loc)])
                                 (and s e sp
                                      (+ (max (- e s) 0) sp)))
                               (srcloc-span s-loc))))]))

;; Like `datum->syntax`, but propagates the source location of
;; a start of a list (if any) to the list itself. That starting
;; item is expected to be a tag that has the span of the whole
;; term already as its location
(define (lists->syntax l)
  (cond
    [(pair? l)
     (define a (car l))
     (define new-l (for/list ([e (in-list l)])
                     (lists->syntax e)))
     (if (syntax? a)
         (datum->syntax #f new-l a a)
         (datum->syntax #f new-l))]
    [else l]))

;; Consume whitespace and comments, including continuing backslashes,
;; where lookahead is needed
;; Arguments/returns:
;;   list of input tokens (after whitespace, comments, and continues)
;;   most recently consumed non-whitesace line (to determine whether
;;     next is on same line); on input; the line can be #f, which means
;;     "treat as same line"; the result is never #f
;;   current line delta (created by continues)
(define (next-of l last-line delta)
  (cond
    [(null? l) (values null (or last-line 0) delta)]
    [else
     (define t (car l))
     (case (token-name t)
       [(whitespace comment)
        (next-of (cdr l) last-line delta)]
       [(continue-operator)
        (define line (token-line t))
        ;; a continue operator not followed only by whitespace and
        ;; comments is just treated as whitespace
        (define next-l (let loop ([l (cdr l)])
                         (cond
                           [(null? l) null]
                           [else (case (token-name (car l))
                                   [(whitespace comment) (loop (cdr l))]
                                   [else l])])))
        (cond
          [(and (pair? next-l)
                (= line (token-line (car next-l))))
           ;; like whitespace:
           (next-of next-l last-line delta)]
          [else
           (next-of next-l
                    ;; whitespace-only lines don't count, so next continues
                    ;; on the same line by definition:
                    #f
                    (+ (if (or (not last-line) (= line last-line))
                           delta
                           0)
                       (token-column t) 1))])]
       [else
        (define line (token-line t))
        (values l
                (or last-line line)
                (if (or (not last-line) (= line last-line))
                    delta
                    0))])]))

(define (next-of/commenting l last-line delta)
  (define-values (rest-l rest-last-line rest-delta) (next-of l last-line delta))
  (cond
    [(pair? rest-l)
     (define-values (group-commenting use-t use-l last-line delta)
       (get-own-line-group-comment (car rest-l) rest-l rest-last-line rest-delta))
     (values group-commenting use-l last-line delta)]
    [else
     (values #f rest-l rest-last-line rest-delta)]))

;; t is at the start of l on input and output
(define (get-own-line-group-comment t l line delta)
  (let loop ([commenting #f] [t t] [l (cdr l)] [line line] [delta delta])
    (case (token-name t)
      [(group-comment)
       (cond
         [((token-line t) . > . line)
          (define-values (next-l last-line next-delta) (next-of l line delta))
          (cond
            [(null? next-l) (fail-no-comment-group t)]
            [(next-line? next-l last-line)
             (when commenting (fail-no-comment-group commenting))
             (loop t (car next-l) (cdr next-l) last-line next-delta)]
            [else
             (values commenting t (cons t next-l) last-line next-delta)])]
         [else
          (fail t "misplaced group comment")])]
      [else
       (values commenting t (cons t l) line delta)])))

(define (next-line? l last-line)
  (and (pair? l)
       ((token-line (car l)) . > . last-line)))

(define (fail-no-comment-group t)
  (fail t "no group for term comment"))

;; Report an error on failure, but then keep parsing anyway
;;  if in recover mode
(define current-recover-mode (make-parameter #f))
(define (fail tok msg)
  (define loc (if (syntax? tok)
                  (srcloc (syntax-source tok)
                          (syntax-line tok)
                          (syntax-column tok)
                          (syntax-position tok)
                          (syntax-span tok))
                  (token-srcloc tok)))
  (cond
    [(current-recover-mode)
     (log-error "~a: ~a" (srcloc->string loc) msg)]
    [else
     (raise
      (exn:fail:read
       (if (error-print-source-location)
           (format "~a: ~a" (srcloc->string loc) msg)
           msg)
       (current-continuation-marks)
       (list loc)))]))

(define (column-next c)
  (if (integer? c)
      (add1 c)
      (add1 (inexact->exact (floor c)))))

(define (column-half-next c)
  (if (integer? c)
      (+ c 0.5)
      (column-next c)))

;; ----------------------------------------

(define (parse-all in #:source [source (object-name in)])
  (define l (lex-all in fail #:source source))
  (if (null? l)
      eof
      (parse-top-groups l)))
  
(module+ main
  (require racket/cmdline)

  (define (parse-all* in)
    (port-count-lines! in)
    (define e (parse-all in))
    (unless (eof-object? e)
      (pretty-write
       (syntax->datum e))))

  (command-line
   #:once-each
   [("--recover") "Continue parsing after an error"
                  (current-recover-mode #t)]
   #:args file
   (if (null? file)
       (parse-all* (current-input-port))
       (for-each (lambda (file)
                   (call-with-input-file*
                    file
                    parse-all*))
                 file))))
