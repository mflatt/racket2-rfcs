#lang racket/base

(provide immutable-string?
         mutable-string?
         immutable-bytes?
         mutable-bytes?
         immutable-vector?
         mutable-vector?
         immutable-hash?
         mutable-hash?)

;; TODO: use `racket/mutability` at the point where it makes sense to
;; depend on a newer Racket

(define (immutable-string? v) (and (string? v) (immutable? v)))
(define (mutable-string? v) (and (string? v) (not (immutable? v))))

(define (immutable-bytes? v) (and (bytes? v) (immutable? v)))
(define (mutable-bytes? v) (and (bytes? v) (not (immutable? v))))

(define (immutable-vector? v) (and (vector? v) (immutable? v)))
(define (mutable-vector? v) (and (vector? v) (not (immutable? v))))

(define (immutable-hash? v) (and (hash? v) (immutable? v)))
(define (mutable-hash? v) (and (hash? v) (not (immutable? v))))
