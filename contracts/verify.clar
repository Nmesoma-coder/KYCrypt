;; KYCrypt - Decentralized KYC Verification Platform
;; Manages KYC verification status for addresses

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_ALREADY_VERIFIED u101)
(define-constant ERR_NOT_VERIFIED u102)
(define-constant ERR_INVALID_STATUS u103)
(define-constant ERR_INVALID_INPUT u104)

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

;; Helper function for input validation
(define-private (is-valid-principal (address principal))
    (and 
        (not (is-eq address (as-contract tx-sender)))  ;; Prevent contract self-interaction
        (not (is-eq address tx-sender))  ;; Prevent sender from manipulating other addresses
    )
)

;; Helper function for KYC data validation
(define-private (is-valid-kyc-data (data (string-utf8 500)))
    (and 
        (> (len data) u0)  ;; Ensure non-empty
        (<= (len data) u500)  ;; Ensure within max length
    )
)

;; Helper function for status validation
(define-private (validate-status-change 
    (current-status uint) 
    (allowed-statuses (list 10 uint)))
    (is-some (index-of allowed-statuses current-status))
)

;; Public functions
(define-public (request-verification (kyc-data (string-utf8 500)))
    (begin
        ;; Validate KYC data input
        (asserts! (is-valid-kyc-data kyc-data) (err ERR_INVALID_INPUT))
        (let 
            ((current-status (get status (get-verification-status tx-sender))))
            (asserts! (is-eq current-status u0) (err ERR_ALREADY_VERIFIED))
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
    )
)

(define-public (verify-address (address principal))
    (begin
        ;; Validate input address
        (try! (validate-input-address address))
        
        ;; Ensure only contract owner can verify
        (try! (validate-owner-only))
        
        ;; Get current verification status
        (let ((current-status (get status (get-verification-status address))))
            ;; Validate status for verification
            (asserts! (validate-status-change current-status (list u1)) (err ERR_INVALID_STATUS))
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
    )
)

(define-public (reject-verification (address principal))
    (begin
        ;; Validate input address
        (try! (validate-input-address address))
        
        ;; Ensure only contract owner can reject
        (try! (validate-owner-only))
        
        ;; Get current verification status
        (let ((current-status (get status (get-verification-status address))))
            ;; Validate status for rejection
            (asserts! (validate-status-change current-status (list u1)) (err ERR_INVALID_STATUS))
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
    )
)

(define-public (revoke-verification (address principal))
    (begin
        ;; Validate input address
        (try! (validate-input-address address))
        
        ;; Ensure only contract owner can revoke
        (try! (validate-owner-only))
        
        ;; Get current verification status
        (let ((current-status (get status (get-verification-status address))))
            ;; Validate status for revocation
            (asserts! (validate-status-change current-status (list u1 u2)) (err ERR_INVALID_STATUS))
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
    )
)

;; Private function to validate input address
(define-private (validate-input-address (address principal))
    (ok (asserts! (is-valid-principal address) (err ERR_INVALID_INPUT)))
)

;; Private function to validate owner-only operations
(define-private (validate-owner-only)
    (ok (asserts! (is-contract-owner tx-sender) (err ERR_UNAUTHORIZED)))
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        ;; Validate new owner address
        (try! (validate-input-address new-owner))
        
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
    })

