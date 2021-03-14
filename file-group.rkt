#lang racket/base


(require racket/contract/base)


(provide
 (contract-out
  [file-groups-resolve (-> (sequence/c file-group?) (listof complete-path?))]
  [file-group? predicate/c]
  [single-file-group? predicate/c]
  [single-file-group (-> path-string? single-file-group?)]
  [directory-file-group? predicate/c]
  [directory-file-group (-> path-string? directory-file-group?)]
  [package-file-group? predicate/c]
  [package-file-group (-> string? package-file-group?)]))


(require fancy-app
         pkg/lib
         racket/file
         racket/match
         racket/path
         racket/sequence
         racket/string
         rebellion/collection/list
         rebellion/private/guarded-block
         rebellion/streaming/transducer)


;@----------------------------------------------------------------------------------------------------


(struct file-group () #:transparent)


(struct single-file-group file-group (path)
  #:transparent
  #:guard (λ (path _) (simple-form-path path)))


(struct directory-file-group file-group (path)
  #:transparent
  #:guard (λ (path _) (simple-form-path path)))


(struct package-file-group file-group (package-name)
  #:transparent
  #:guard (λ (package-name _) (string->immutable-string package-name)))


(define (file-groups-resolve groups)
  (transduce groups (append-mapping file-group-resolve) (deduplicating) #:into into-list))


(define (file-group-resolve group)
  (define files
    (match group
      [(single-file-group path) (list path)]
      [(directory-file-group path) (sequence->list (in-directory path))]
      [(package-file-group package-name)
       (sequence->list (in-directory (simple-form-path (pkg-directory package-name))))]))
  (transduce files (filtering rkt-file?) #:into into-list))


(define/guard (rkt-file? path)
  (guard (path-has-extension? path #".rkt") else
    #false)
  (define content (file->string path))
  (string-prefix? content "#lang racket/base"))