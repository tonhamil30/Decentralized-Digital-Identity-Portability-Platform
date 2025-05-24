;; Identity Migration Contract
;; Manages transfer of identities between systems

(define-map migration-requests
  { migration-id: (string-ascii 64) }
  {
    user-principal: principal,
    source-system: (string-ascii 64),
    target-system: (string-ascii 64),
    identity-hash: (buff 32),
    status: (string-ascii 16),
    requested-at: uint,
    completed-at: (optional uint)
  }
)

(define-map user-migrations
  { user: principal }
  { active-migrations: (list 10 (string-ascii 64)) }
)

(define-data-var migration-counter uint u0)

;; Error codes
(define-constant ERR-MIGRATION-NOT-FOUND (err u200))
(define-constant ERR-UNAUTHORIZED-USER (err u201))
(define-constant ERR-MIGRATION-IN-PROGRESS (err u202))
(define-constant ERR-INVALID-STATUS (err u203))

;; Status constants
(define-constant STATUS-PENDING "pending")
(define-constant STATUS-IN-PROGRESS "in-progress")
(define-constant STATUS-COMPLETED "completed")
(define-constant STATUS-FAILED "failed")

;; Initiate identity migration
(define-public (initiate-migration (source-system (string-ascii 64))
                                  (target-system (string-ascii 64))
                                  (identity-hash (buff 32)))
  (let ((migration-id (int-to-ascii (var-get migration-counter))))
    (begin
      (var-set migration-counter (+ (var-get migration-counter) u1))
      (map-set migration-requests
        { migration-id: migration-id }
        {
          user-principal: tx-sender,
          source-system: source-system,
          target-system: target-system,
          identity-hash: identity-hash,
          status: STATUS-PENDING,
          requested-at: block-height,
          completed-at: none
        }
      )
      (ok migration-id)
    )
  )
)

;; Update migration status
(define-public (update-migration-status (migration-id (string-ascii 64))
                                       (new-status (string-ascii 16)))
  (match (map-get? migration-requests { migration-id: migration-id })
    migration
    (begin
      (asserts! (is-eq tx-sender (get user-principal migration)) ERR-UNAUTHORIZED-USER)
      (map-set migration-requests
        { migration-id: migration-id }
        (merge migration {
          status: new-status,
          completed-at: (if (is-eq new-status STATUS-COMPLETED)
                           (some block-height)
                           (get completed-at migration))
        })
      )
      (ok true)
    )
    ERR-MIGRATION-NOT-FOUND
  )
)

;; Get migration details
(define-read-only (get-migration (migration-id (string-ascii 64)))
  (map-get? migration-requests { migration-id: migration-id })
)

;; Get user's active migrations
(define-read-only (get-user-migrations (user principal))
  (map-get? user-migrations { user: user })
)

;; Check if migration is complete
(define-read-only (is-migration-complete (migration-id (string-ascii 64)))
  (match (map-get? migration-requests { migration-id: migration-id })
    migration (ok (is-eq (get status migration) STATUS-COMPLETED))
    ERR-MIGRATION-NOT-FOUND
  )
)
