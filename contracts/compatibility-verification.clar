;; Compatibility Verification Contract
;; Ensures cross-platform functionality

(define-map system-compatibility
  { system-a: (string-ascii 64), system-b: (string-ascii 64) }
  {
    compatible: bool,
    compatibility-score: uint,
    supported-features: (list 20 (string-ascii 32)),
    verified-at: uint
  }
)

(define-map system-standards
  { system-id: (string-ascii 64) }
  {
    standards: (list 10 (string-ascii 32)),
    version: (string-ascii 16),
    last-updated: uint
  }
)

(define-data-var contract-admin principal tx-sender)

;; Error codes
(define-constant ERR-UNAUTHORIZED-ADMIN (err u300))
(define-constant ERR-INCOMPATIBLE-SYSTEMS (err u301))
(define-constant ERR-SYSTEM-NOT-FOUND (err u302))

;; Register system standards
(define-public (register-system-standards (system-id (string-ascii 64))
                                         (standards (list 10 (string-ascii 32)))
                                         (version (string-ascii 16)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED-ADMIN)
    (map-set system-standards
      { system-id: system-id }
      {
        standards: standards,
        version: version,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

;; Set compatibility between systems
(define-public (set-compatibility (system-a (string-ascii 64))
                                 (system-b (string-ascii 64))
                                 (compatible bool)
                                 (compatibility-score uint)
                                 (supported-features (list 20 (string-ascii 32))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED-ADMIN)
    (map-set system-compatibility
      { system-a: system-a, system-b: system-b }
      {
        compatible: compatible,
        compatibility-score: compatibility-score,
        supported-features: supported-features,
        verified-at: block-height
      }
    )
    ;; Also set reverse compatibility
    (map-set system-compatibility
      { system-a: system-b, system-b: system-a }
      {
        compatible: compatible,
        compatibility-score: compatibility-score,
        supported-features: supported-features,
        verified-at: block-height
      }
    )
    (ok true)
  )
)

;; Check system compatibility
(define-read-only (check-compatibility (system-a (string-ascii 64))
                                      (system-b (string-ascii 64)))
  (match (map-get? system-compatibility { system-a: system-a, system-b: system-b })
    compat (ok (get compatible compat))
    (err ERR-INCOMPATIBLE-SYSTEMS)
  )
)

;; Get compatibility details
(define-read-only (get-compatibility-details (system-a (string-ascii 64))
                                            (system-b (string-ascii 64)))
  (map-get? system-compatibility { system-a: system-a, system-b: system-b })
)

;; Get system standards
(define-read-only (get-system-standards (system-id (string-ascii 64)))
  (map-get? system-standards { system-id: system-id })
)
