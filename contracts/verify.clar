;; STX KYC Platform Contract
;; Manages KYC verification status for addresses

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_VERIFIED (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-map verified-addresses 
    principal 
    {
        status: uint,  ;; 0: not verified, 1: pending, 2: verified, 3: rejected
        timestamp: uint,
        kyc-data: (string-utf8 500),
        verifier: principal
    }
)

;; Read-only functions
(define-read-only (get-verification-status (address principal))
    (match (map-get? verified-addresses address)
        status status
        (err u404)
    )
)

(define-read-only (is-contract-owner (address principal))
    (is-eq address (var-get contract-owner))
)

;; Public functions
(define-public (request-verification (kyc-data (string-utf8 500)))
    (let ((current-status (get-verification-status tx-sender)))
        (match current-status
            success (if (is-eq (get status success) u0)
                (ok (map-set verified-addresses tx-sender
                    {
                        status: u1,
                        timestamp: block-height,
                        kyc-data: kyc-data,
                        verifier: tx-sender
                    }))
                ERR_ALREADY_VERIFIED)
            (ok (map-set verified-addresses tx-sender
                {
                    status: u1,
                    timestamp: block-height,
                    kyc-data: kyc-data,
                    verifier: tx-sender
                }))
        )
    )
)

(define-public (verify-address (address principal))
    (begin
        (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
        (match (map-get? verified-addresses address)
            existing-data (ok (map-set verified-addresses address
                {
                    status: u2,
                    timestamp: block-height,
                    kyc-data: (get kyc-data existing-data),
                    verifier: tx-sender
                }))
            ERR_NOT_VERIFIED
        )
    )
)

(define-public (reject-verification (address principal))
    (begin
        (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
        (match (map-get? verified-addresses address)
            existing-data (ok (map-set verified-addresses address
                {
                    status: u3,
                    timestamp: block-height,
                    kyc-data: (get kyc-data existing-data),
                    verifier: tx-sender
                }))
            ERR_NOT_VERIFIED
        )
    )
)

(define-public (revoke-verification (address principal))
    (begin
        (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
        (match (map-get? verified-addresses address)
            existing-data (ok (map-set verified-addresses address
                {
                    status: u0,
                    timestamp: block-height,
                    kyc-data: (get kyc-data existing-data),
                    verifier: tx-sender
                }))
            ERR_NOT_VERIFIED
        )
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
        (ok (var-set contract-owner new-owner))
    )
)