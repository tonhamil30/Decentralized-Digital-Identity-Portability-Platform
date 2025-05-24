;; Identity Provider Verification Contract
;; Validates credential issuers and manages their registration

(define-map verified-providers
  { provider-id: (string-ascii 64) }
  {
    name: (string-ascii 128),
    public-key: (buff 33),
    verification-level: uint,
    active: bool,
    registered-at: uint
  }
)

(define-map provider-credentials
  { provider-id: (string-ascii 64), credential-type: (string-ascii 32) }
  { authorized: bool, expires-at: uint }
)

(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PROVIDER-NOT-FOUND (err u101))
(define-constant ERR-PROVIDER-INACTIVE (err u102))
(define-constant ERR-CREDENTIAL-EXPIRED (err u103))

;; Register a new identity provider
(define-public (register-provider (provider-id (string-ascii 64))
                                 (name (string-ascii 128))
                                 (public-key (buff 33))
                                 (verification-level uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (map-set verified-providers
      { provider-id: provider-id }
      {
        name: name,
        public-key: public-key,
        verification-level: verification-level,
        active: true,
        registered-at: block-height
      }
    )
    (ok true)
  )
)

;; Verify if a provider is valid and active
(define-read-only (is-provider-verified (provider-id (string-ascii 64)))
  (match (map-get? verified-providers { provider-id: provider-id })
    provider (ok (get active provider))
    (err ERR-PROVIDER-NOT-FOUND)
  )
)

;; Authorize credential type for provider
(define-public (authorize-credential (provider-id (string-ascii 64))
                                   (credential-type (string-ascii 32))
                                   (expires-at uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (is-ok (is-provider-verified provider-id)) ERR-PROVIDER-NOT-FOUND)
    (map-set provider-credentials
      { provider-id: provider-id, credential-type: credential-type }
      { authorized: true, expires-at: expires-at }
    )
    (ok true)
  )
)

;; Check if provider can issue specific credential type
(define-read-only (can-issue-credential (provider-id (string-ascii 64))
                                       (credential-type (string-ascii 32)))
  (match (map-get? provider-credentials { provider-id: provider-id, credential-type: credential-type })
    cred (if (and (get authorized cred) (> (get expires-at cred) block-height))
           (ok true)
           (err ERR-CREDENTIAL-EXPIRED))
    (err ERR-PROVIDER-NOT-FOUND)
  )
)

;; Get provider details
(define-read-only (get-provider (provider-id (string-ascii 64)))
  (map-get? verified-providers { provider-id: provider-id })
)
