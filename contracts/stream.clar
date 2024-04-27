;; errr codes
(define-constant ERR_UNAUTHORIZED (err u0))
(define-constant ERR_INVALID_SIGNATURE (err u1))
(define-constant ERR_STREAM_STILL_ACTIVE (err u2))
(define-constant ERR_STREAM_NOT_FOUND (err u3))

;; data vars
(define-data-var latest-stream-id uint u0)

;; streams map
(define-map streams
    uint ;; stream id
    {
        sender: principal,
        recipient: principal,
        balance: uint,
        withdrawn-balance: uint,
        payment-per-block: uint,
        timeframe: (tuple (start-block uint) (stop-block uint))
    }
)

;; create a new stream
(define-public (stream-to
    (recipient principal)
    (initial-balance uint)
    (timeframe (tuple (start-block uint) (stop-block uint)))
    (payment-per-block uint)
)
    (let
        (
            (stream {
                sender: tx-sender,
                recipient: recipient,
                balance: initial-balance,
                withdrawn-balance: u0,
                payment-per-block: payment-per-block,
                timeframe: timeframe
            })
            (current-stream-id (var-get latest-stream-id))
        )
    ;; contract-call? takes in (asset identifier, function name, amount, sender, recipient) arguments
	;; for the `recipient` - we do `(as-contract tx-sender)`
	;; `as-contract` switches the `tx-sender` variable to be the contract principal
	;; inside it's scope
	;; so doing `as-contract tx-sender` gives us the contract address itself
	;; this is like doing address(this) in Solidity
    (try! (contract-call? .sbtc transfer initial-balance tx-sender (as-contract tx-sender) none))
    (map-set streams current-stream-id stream)
    (var-set latest-stream-id (+ current-stream-id u1))
    (ok current-stream-id)
    )
)

;; increase locked stx balance for a stream
(define-public (refuel
    (stream-id uint)
    (amount uint)
    )
    (let (
        (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get sender stream)) ERR_UNAUTHORIZED)
        (try! (contract-call? .sbtc transfer amount tx-sender (as-contract tx-sender) none))
        (map-set streams
            stream-id
            (merge stream {balance: (+ amount (get balance stream))})
        )
        (ok amount)
    )
)

;; Calculate the number of blocks a stream has been active
(define-read-only (calculate-block-delta
    (timeframe (tuple (start-block uint) (stop-block uint)))
  )
  (let (
    (start-block (get start-block timeframe))
    (stop-block (get stop-block timeframe))

    (delta
      (if (<= block-height start-block)
        ;; then
        u0
        ;; else
        (if (< block-height stop-block)
          ;; then
          (- block-height start-block)
          ;; else
          (- stop-block start-block)
        )
      )
    )
  )
    delta
  )
)

;; Check balance for a party involved in a stream
(define-read-only (balance-of
    (stream-id uint)
    (who principal)
  )
  (let (
    (stream (unwrap-panic (map-get? streams stream-id)))
    (block-delta (calculate-block-delta (get timeframe stream)))
    (recipient-balance (* block-delta (get payment-per-block stream)))
  )
    (if (is-eq who (get recipient stream))
      (- recipient-balance (get withdrawn-balance stream))
      (if (is-eq who (get sender stream))
        (- (get balance stream) recipient-balance)
        u0
      )
    )
  )
)

;; Withdraw received tokens
(define-public (withdraw
    (stream-id uint)
  )
  (let (
    (stream (unwrap-panic (map-get? streams stream-id)))
    (balance (balance-of stream-id tx-sender))
    (updated-stream
        (merge stream
            {withdrawn-balance:
                (+ balance (get withdrawn-balance stream))
            })
    )
  )
      (asserts! (is-eq tx-sender (get recipient stream)) ERR_UNAUTHORIZED)
      (map-set streams
        stream-id
        updated-stream
      )
      (try! (as-contract (contract-call? .sbtc transfer balance tx-sender (get recipient stream) none)))
      (ok balance)
  )
)

;; Withdraw excess locked tokens
(define-public (refund
    (stream-id uint)
  )
  (let (
    (stream (unwrap-panic (map-get? streams stream-id)))
    (balance (balance-of stream-id (get sender stream)))
    (updated-stream
        (merge stream
            {balance:
                (- (get balance stream) balance)
            })
    )
  )
  (begin
      (asserts! (is-eq tx-sender (get sender stream)) ERR_UNAUTHORIZED)
      (asserts! (< (get stop-block (get timeframe stream)) block-height) ERR_STREAM_STILL_ACTIVE)
      (map-set streams
        stream-id
        updated-stream
      )
      (try! (as-contract (contract-call? .sbtc transfer balance tx-sender (get sender stream) none)))
      (ok balance)
    )
  )
)

;; Get hash of stream
(define-read-only (hash-stream
    (stream-id uint)
    (new-payment-per-block uint)
    (new-timeframe (tuple (start-block uint) (stop-block uint)))
  )
  (let (
    (stream (unwrap-panic (map-get? streams stream-id)))
    (msg (concat (concat (unwrap-panic (to-consensus-buff? stream)) (unwrap-panic (to-consensus-buff? new-payment-per-block))) (unwrap-panic (to-consensus-buff? new-timeframe))))
  )
    (sha256 msg)
  )
)

;; Signature verification
(define-read-only (validate-signature (hash (buff 32)) (signature (buff 65)) (signer principal))
    (is-eq
        (principal-of? (unwrap! (secp256k1-recover? hash signature) false))
        (ok signer)
    )
)

;; Update stream configuration
(define-public (update-details
    (stream-id uint)
    (payment-per-block uint)
    (timeframe (tuple (start-block uint) (stop-block uint)))
    (signer principal)
    (signature (buff 65))
  )
  (let (
    (stream (unwrap-panic (map-get? streams stream-id)))
    (updated-stream
        (merge stream
            {payment-per-block: payment-per-block, timeframe: timeframe}
        )
    )
  )
      (asserts! (validate-signature (hash-stream stream-id payment-per-block timeframe) signature signer) ERR_INVALID_SIGNATURE)
      (asserts!
        (or
          (and (is-eq (get sender stream) tx-sender) (is-eq (get recipient stream) signer))
          (and (is-eq (get sender stream) signer) (is-eq (get recipient stream) tx-sender))
        )
        ERR_UNAUTHORIZED
      )
      (map-set streams
        stream-id
        updated-stream
      )
      (ok true)
    )
)