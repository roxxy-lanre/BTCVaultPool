
;; title: BTCVaultPool
;; version: 1.0.0
;; summary: Cross-chain AMM liquidity pool for Bitcoin vault services on Stacks
;; description: A decentralized liquidity pool that enables automated market making
;;              for Bitcoin vault services, providing cross-chain functionality

;; traits
(define-trait vault-token-trait
  ((transfer (uint principal principal (optional (buff 34))) (response bool uint))
   (get-name () (response (string-ascii 32) uint))
   (get-symbol () (response (string-ascii 32) uint))
   (get-decimals () (response uint uint))
   (get-balance (principal) (response uint uint))
   (get-total-supply () (response uint uint))))

;; token definitions
(define-fungible-token btc-vault-lp)

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-insufficient-liquidity (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-slippage-exceeded (err u104))
(define-constant err-vault-not-found (err u105))
(define-constant err-vault-already-exists (err u106))
(define-constant err-pool-paused (err u107))

;; Pool configuration constants
(define-constant min-liquidity u1000)
(define-constant fee-rate u30) ;; 0.3% = 30/10000
(define-constant fee-denominator u10000)

;; data vars
(define-data-var pool-paused bool false)
(define-data-var total-btc-reserves uint u0)
(define-data-var total-stx-reserves uint u0)
(define-data-var protocol-fee-collector principal contract-owner)

;; data maps
(define-map vaults
  principal
  {
    btc-balance: uint,
    stx-balance: uint,
    vault-fee: uint,
    active: bool,
    created-at: uint
  })

(define-map liquidity-providers
  principal
  {
    lp-tokens: uint,
    btc-provided: uint,
    stx-provided: uint,
    last-deposit: uint
  })

(define-map vault-metrics
  principal
  {
    total-volume: uint,
    total-fees-earned: uint,
    utilization-rate: uint
  })

;; public functions

;; Initialize a new vault
(define-public (create-vault (vault-fee uint))
  (let ((vault-exists (is-some (map-get? vaults tx-sender))))
    (if vault-exists
      err-vault-already-exists
      (begin
        (map-set vaults tx-sender {
          btc-balance: u0,
          stx-balance: u0,
          vault-fee: vault-fee,
          active: true,
          created-at: block-height
        })
        (map-set vault-metrics tx-sender {
          total-volume: u0,
          total-fees-earned: u0,
          utilization-rate: u0
        })
        (ok true)))))

;; Add liquidity to the pool
(define-public (add-liquidity (btc-amount uint) (stx-amount uint) (min-lp-tokens uint))
  (let (
    (current-btc-reserves (var-get total-btc-reserves))
    (current-stx-reserves (var-get total-stx-reserves))
    (total-supply (ft-get-supply btc-vault-lp))
  )
    (asserts! (not (var-get pool-paused)) err-pool-paused)
    (asserts! (> btc-amount u0) err-invalid-amount)
    (asserts! (> stx-amount u0) err-invalid-amount)

    (let ((lp-tokens-to-mint
           (if (is-eq total-supply u0)
             ;; Initial liquidity provision
             (- (* btc-amount stx-amount) min-liquidity)
             ;; Subsequent liquidity provision
             (min
               (/ (* btc-amount total-supply) current-btc-reserves)
               (/ (* stx-amount total-supply) current-stx-reserves)))))

      (asserts! (>= lp-tokens-to-mint min-lp-tokens) err-slippage-exceeded)

      ;; Update reserves
      (var-set total-btc-reserves (+ current-btc-reserves btc-amount))
      (var-set total-stx-reserves (+ current-stx-reserves stx-amount))

      ;; Mint LP tokens
      (try! (ft-mint? btc-vault-lp lp-tokens-to-mint tx-sender))

      ;; Update liquidity provider data
      (let ((existing-provider (default-to
                                {lp-tokens: u0, btc-provided: u0, stx-provided: u0, last-deposit: u0}
                                (map-get? liquidity-providers tx-sender))))
        (map-set liquidity-providers tx-sender {
          lp-tokens: (+ (get lp-tokens existing-provider) lp-tokens-to-mint),
          btc-provided: (+ (get btc-provided existing-provider) btc-amount),
          stx-provided: (+ (get stx-provided existing-provider) stx-amount),
          last-deposit: block-height
        }))

      (ok lp-tokens-to-mint))))

;; Remove liquidity from the pool
(define-public (remove-liquidity (lp-tokens uint) (min-btc-out uint) (min-stx-out uint))
  (let (
    (total-supply (ft-get-supply btc-vault-lp))
    (current-btc-reserves (var-get total-btc-reserves))
    (current-stx-reserves (var-get total-stx-reserves))
    (user-balance (ft-get-balance btc-vault-lp tx-sender))
  )
    (asserts! (not (var-get pool-paused)) err-pool-paused)
    (asserts! (> lp-tokens u0) err-invalid-amount)
    (asserts! (<= lp-tokens user-balance) err-insufficient-balance)

    (let (
      (btc-out (/ (* lp-tokens current-btc-reserves) total-supply))
      (stx-out (/ (* lp-tokens current-stx-reserves) total-supply))
    )
      (asserts! (>= btc-out min-btc-out) err-slippage-exceeded)
      (asserts! (>= stx-out min-stx-out) err-slippage-exceeded)

      ;; Burn LP tokens
      (try! (ft-burn? btc-vault-lp lp-tokens tx-sender))

      ;; Update reserves
      (var-set total-btc-reserves (- current-btc-reserves btc-out))
      (var-set total-stx-reserves (- current-stx-reserves stx-out))

      ;; Update liquidity provider data
      (let ((provider-data (unwrap-panic (map-get? liquidity-providers tx-sender))))
        (map-set liquidity-providers tx-sender {
          lp-tokens: (- (get lp-tokens provider-data) lp-tokens),
          btc-provided: (get btc-provided provider-data),
          stx-provided: (get stx-provided provider-data),
          last-deposit: (get last-deposit provider-data)
        }))

      (ok {btc-out: btc-out, stx-out: stx-out}))))

;; Swap BTC for STX
(define-public (swap-btc-for-stx (btc-amount uint) (min-stx-out uint))
  (let (
    (current-btc-reserves (var-get total-btc-reserves))
    (current-stx-reserves (var-get total-stx-reserves))
  )
    (asserts! (not (var-get pool-paused)) err-pool-paused)
    (asserts! (> btc-amount u0) err-invalid-amount)
    (asserts! (< btc-amount current-btc-reserves) err-insufficient-liquidity)

    (let (
      (btc-amount-with-fee (- btc-amount (/ (* btc-amount fee-rate) fee-denominator)))
      (stx-out (/ (* btc-amount-with-fee current-stx-reserves)
                  (+ current-btc-reserves btc-amount-with-fee)))
    )
      (asserts! (>= stx-out min-stx-out) err-slippage-exceeded)
      (asserts! (> stx-out u0) err-insufficient-liquidity)

      ;; Update reserves
      (var-set total-btc-reserves (+ current-btc-reserves btc-amount))
      (var-set total-stx-reserves (- current-stx-reserves stx-out))

      (ok stx-out))))

;; Swap STX for BTC
(define-public (swap-stx-for-btc (stx-amount uint) (min-btc-out uint))
  (let (
    (current-btc-reserves (var-get total-btc-reserves))
    (current-stx-reserves (var-get total-stx-reserves))
  )
    (asserts! (not (var-get pool-paused)) err-pool-paused)
    (asserts! (> stx-amount u0) err-invalid-amount)
    (asserts! (< stx-amount current-stx-reserves) err-insufficient-liquidity)

    (let (
      (stx-amount-with-fee (- stx-amount (/ (* stx-amount fee-rate) fee-denominator)))
      (btc-out (/ (* stx-amount-with-fee current-btc-reserves)
                  (+ current-stx-reserves stx-amount-with-fee)))
    )
      (asserts! (>= btc-out min-btc-out) err-slippage-exceeded)
      (asserts! (> btc-out u0) err-insufficient-liquidity)

      ;; Update reserves
      (var-set total-stx-reserves (+ current-stx-reserves stx-amount))
      (var-set total-btc-reserves (- current-btc-reserves btc-out))

      (ok btc-out))))

;; Update vault status
(define-public (update-vault-status (active bool))
  (let ((vault-data (unwrap! (map-get? vaults tx-sender) err-vault-not-found)))
    (map-set vaults tx-sender (merge vault-data {active: active}))
    (ok true)))

;; Admin functions
(define-public (pause-pool)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set pool-paused true)
    (ok true)))

(define-public (unpause-pool)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set pool-paused false)
    (ok true)))

(define-public (set-fee-collector (new-collector principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set protocol-fee-collector new-collector)
    (ok true)))

;; read only functions

;; Get pool reserves
(define-read-only (get-pool-reserves)
  {
    btc-reserves: (var-get total-btc-reserves),
    stx-reserves: (var-get total-stx-reserves),
    total-lp-supply: (ft-get-supply btc-vault-lp)
  })

;; Get vault info
(define-read-only (get-vault-info (vault-owner principal))
  (map-get? vaults vault-owner))

;; Get liquidity provider info
(define-read-only (get-lp-info (provider principal))
  (map-get? liquidity-providers provider))

;; Calculate swap output
(define-read-only (get-swap-output (input-amount uint) (input-reserve uint) (output-reserve uint))
  (let ((input-with-fee (- input-amount (/ (* input-amount fee-rate) fee-denominator))))
    (/ (* input-with-fee output-reserve) (+ input-reserve input-with-fee))))

;; Get current price ratio
(define-read-only (get-price-ratio)
  (let (
    (btc-reserves (var-get total-btc-reserves))
    (stx-reserves (var-get total-stx-reserves))
  )
    (if (and (> btc-reserves u0) (> stx-reserves u0))
      (some (/ (* stx-reserves u1000000) btc-reserves))
      none)))

;; Check if pool is paused
(define-read-only (is-pool-paused)
  (var-get pool-paused))

;; Get vault metrics
(define-read-only (get-vault-metrics (vault-owner principal))
  (map-get? vault-metrics vault-owner))

;; private functions

;; Calculate minimum of two numbers
(define-private (min (a uint) (b uint))
  (if (<= a b) a b))

;; Calculate maximum of two numbers
(define-private (max (a uint) (b uint))
  (if (>= a b) a b))
