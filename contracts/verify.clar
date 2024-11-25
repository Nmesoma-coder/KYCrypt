;; KYCrypt - Decentralized KYC Verification Platform
;; Manages KYC verification status for addresses

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_ALREADY_VERIFIED u101)
(define-constant ERR_NOT_VERIFIED u102)
(define-constant ERR_INVALID_STATUS u103)

;; Data variables
(define-data-var contract-owner principal tx-sender)

;; Verification status map
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
    (default-to 
        {
            status: u0, 
            timestamp: u0, 
            kyc-data: u"", 
            verifier: tx-sender
        }
        (map-get? verified-addresses address)
    )
)

(define-read-only (is-contract-owner (address principal))
    (is-eq address (var-get contract-owner))
)

;; Helper function for status validation
(define-private (validate-status-change 
    (current-status uint) 
    (allowed-statuses (list 10 uint)))
    (is-some (index-of allowed-statuses current-status))
)

;; Public functions
(define-public (request-verification (kyc-data (string-utf8 500)))
    (let 
        ((current-status (get status (get-verification-status tx-sender))))
        (if (is-eq current-status u0)
            (begin 
                (map-set verified-addresses tx-sender
                    {
                        status: u1,
                        timestamp: block-height,
                        kyc-data: kyc-data,
                        verifier: tx-sender
                    }
                )
                (ok true)
            )
            (err ERR_ALREADY_VERIFIED)
        )
    )
)

(define-public (verify-address (address principal))
    (begin
        ;; Ensure only contract owner can verify
        (try! (validate-owner-only))
        
        ;; Get current verification status
        (let ((current-status (get status (get-verification-status address))))
            ;; Validate status for verification
            (if (validate-status-change current-status (list u1))
                (begin 
                    (map-set verified-addresses address
                        {
                            status: u2,
                            timestamp: block-height,
                            kyc-data: (get kyc-data (get-verification-status address)),
                            verifier: tx-sender
                        }
                    )
                    (ok true)
                )
                (err ERR_INVALID_STATUS)
            )
        )
    )
)

(define-public (reject-verification (address principal))
    (begin
        ;; Ensure only contract owner can reject
        (try! (validate-owner-only))
        
        ;; Get current verification status
        (let ((current-status (get status (get-verification-status address))))
            ;; Validate status for rejection
            (if (validate-status-change current-status (list u1))
                (begin 
                    (map-set verified-addresses address
                        {
                            status: u3,
                            timestamp: block-height,
                            kyc-data: (get kyc-data (get-verification-status address)),
                            verifier: tx-sender
                        }
                    )
                    (ok true)
                )
                (err ERR_INVALID_STATUS)
            )
        )
    )
)

(define-public (revoke-verification (address principal))
    (begin
        ;; Ensure only contract owner can revoke
        (try! (validate-owner-only))
        
        ;; Get current verification status
        (let ((current-status (get status (get-verification-status address))))
            ;; Validate status for revocation
            (if (validate-status-change current-status (list u1 u2))
                (begin 
                    (map-set verified-addresses address
                        {
                            status: u0,
                            timestamp: block-height,
                            kyc-data: (get kyc-data (get-verification-status address)),
                            verifier: tx-sender
                        }
                    )
                    (ok true)
                )
                (err ERR_INVALID_STATUS)
            )
        )
    )
)

;; Private function to validate owner-only operations
(define-private (validate-owner-only)
    (if (is-contract-owner tx-sender)
        (ok true)
        (err ERR_UNAUTHORIZED)
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        ;; Ensure only current owner can transfer
        (try! (validate-owner-only))
        
        ;; Update contract owner
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; Initialize the contract with deployer's address
(map-set verified-addresses tx-sender
    {
        status: u0,
        timestamp: block-height,
        kyc-data: u"",
        verifier: tx-sender
    }
)