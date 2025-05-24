;; Data Integrity Contract
;; Maintains identity consistency during transfers

(define-map identity-hashes
  { identity-id: (string-ascii 64) }
  {
    current-hash: (buff 32),
    previous-hash: (optional (buff 32)),
    owner: principal,
    last-updated: uint,
    integrity-verified: bool
  }
)

(define-map hash-history
  { identity-id: (string-ascii 64), block-height: uint }
  { hash-value: (buff 32), operation: (string-ascii 16) }
)

;; Error codes
(define-constant ERR-IDENTITY-NOT-FOUND (err u400))
(define-constant ERR-UNAUTHORIZED-OWNER (err u401))
(define-constant ERR-INTEGRITY-VIOLATION (err u402))
(define-constant ERR-HASH-MISMATCH (err u403))

;; Register new identity hash
(define-public (register-identity (identity-id (string-ascii 64))
                                 (initial-hash (buff 32)))
  (begin
    (map-set identity-hashes
      { identity-id: identity-id }
      {
        current-hash: initial-hash,
        previous-hash: none,
        owner: tx-sender,
        last-updated: block-height,
        integrity-verified: true
      }
    )
    (map-set hash-history
      { identity-id: identity-id, block-height: block-height }
      { hash-value: initial-hash, operation: "create" }
    )
    (ok true)
  )
)

;; Update identity hash
(define-public (update-identity-hash (identity-id (string-ascii 64))
                                   (new-hash (buff 32)))
  (match (map-get? identity-hashes { identity-id: identity-id })
    identity
    (begin
      (asserts! (is-eq tx-sender (get owner identity)) ERR-UNAUTHORIZED-OWNER)
      (map-set identity-hashes
        { identity-id: identity-id }
        (merge identity {
          current-hash: new-hash,
          previous-hash: (some (get current-hash identity)),
          last-updated: block-height,
          integrity-verified: true
        })
      )
      (map-set hash-history
        { identity-id: identity-id, block-height: block-height }
        { hash-value: new-hash, operation: "update" }
      )
      (ok true)
    )
    ERR-IDENTITY-NOT-FOUND
  )
)

;; Verify identity integrity
(define-public (verify-integrity (identity-id (string-ascii 64))
                                (expected-hash (buff 32)))
  (match (map-get? identity-hashes { identity-id: identity-id })
    identity
    (if (is-eq (get current-hash identity) expected-hash)
      (ok true)
      (begin
        (map-set identity-hashes
          { identity-id: identity-id }
          (merge identity { integrity-verified: false })
        )
        ERR-HASH-MISMATCH
      )
    )
    ERR-IDENTITY-NOT-FOUND
  )
)

;; Get identity hash details
(define-read-only (get-identity-hash (identity-id (string-ascii 64)))
  (map-get? identity-hashes { identity-id: identity-id })
)

;; Check integrity status
(define-read-only (is-integrity-verified (identity-id (string-ascii 64)))
  (match (map-get? identity-hashes { identity-id: identity-id })
    identity (ok (get integrity-verified identity))
    ERR-IDENTITY-NOT-FOUND
  )
)

;; Get hash history
(define-read-only (get-hash-history (identity-id (string-ascii 64))
                                   (block-height uint))
  (map-get? hash-history { identity-id: identity-id, block-height: block-height })
)
