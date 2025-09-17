(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-POOL-NOT-FOUND (err u3))
(define-constant ERR-ALREADY-STAKED (err u4))
(define-constant ERR-NOT-STAKED (err u5))
(define-constant ERR-INVALID-AMOUNT (err u6))
(define-constant ERR-COOLDOWN-ACTIVE (err u7))
(define-constant ERR-POOL-INACTIVE (err u8))

(define-data-var contract-owner principal tx-sender)
(define-data-var total-pools uint u0)
(define-data-var emergency-shutdown bool false)

(define-map pools
  { pool-id: uint }
  {
    name: (string-ascii 50),
    active: bool,
    total-staked: uint,
    reward-rate: uint,
    min-stake: uint,
    created-at: uint
  }
)

(define-map user-stakes
  { user: principal, pool-id: uint }
  {
    amount: uint,
    stake-time: uint,
    last-claim: uint,
    total-rewards: uint
  }
)

(define-map user-pool-count
  { user: principal }
  { count: uint }
)

(define-private (get-pool (pool-id uint))
  (map-get? pools { pool-id: pool-id })
)

(define-private (get-user-stake (user principal) (pool-id uint))
  (map-get? user-stakes { user: user, pool-id: pool-id })
)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (calculate-rewards (amount uint) (rate uint) (blocks-elapsed uint))
  (/ (* (* amount rate) blocks-elapsed) u100000000)
)

(define-private (get-blocks-elapsed (start-block uint))
  (if (> stacks-block-height start-block)
    (- stacks-block-height start-block)
    u0
  )
)

(define-read-only (get-pool-info (pool-id uint))
  (get-pool pool-id)
)

(define-read-only (get-user-stake-info (user principal) (pool-id uint))
  (get-user-stake user pool-id)
)

(define-read-only (get-pending-rewards (user principal) (pool-id uint))
  (match (get-user-stake user pool-id)
    stake-info (let
      (
        (blocks-since-claim (get-blocks-elapsed (get last-claim stake-info)))
        (amount (get amount stake-info))
      )
      (match (get-pool pool-id)
        pool-info (ok (calculate-rewards amount (get reward-rate pool-info) blocks-since-claim))
        (err ERR-POOL-NOT-FOUND)
      )
    )
    (err ERR-NOT-STAKED)
  )
)

(define-read-only (get-total-user-stakes (user principal))
  (default-to u0 (get count (map-get? user-pool-count { user: user })))
)

(define-read-only (get-contract-stats)
  {
    total-pools: (var-get total-pools),
    emergency-shutdown: (var-get emergency-shutdown),
    contract-owner: (var-get contract-owner)
  }
)

(define-public (create-pool (name (string-ascii 50)) (reward-rate uint) (min-stake uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (asserts! (not (var-get emergency-shutdown)) ERR-POOL-INACTIVE)
    (asserts! (> reward-rate u0) ERR-INVALID-AMOUNT)
    (asserts! (> min-stake u0) ERR-INVALID-AMOUNT)
    (let
      (
        (pool-id (+ (var-get total-pools) u1))
      )
      (map-set pools
        { pool-id: pool-id }
        {
          name: name,
          active: true,
          total-staked: u0,
          reward-rate: reward-rate,
          min-stake: min-stake,
          created-at: stacks-block-height
        }
      )
      (var-set total-pools pool-id)
      (ok pool-id)
    )
  )
)

(define-public (stake (pool-id uint) (amount uint))
  (begin
    (asserts! (not (var-get emergency-shutdown)) ERR-POOL-INACTIVE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (match (get-pool pool-id)
      pool-info (begin
        (asserts! (get active pool-info) ERR-POOL-INACTIVE)
        (asserts! (>= amount (get min-stake pool-info)) ERR-INVALID-AMOUNT)
        (asserts! (is-none (get-user-stake tx-sender pool-id)) ERR-ALREADY-STAKED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-stakes
          { user: tx-sender, pool-id: pool-id }
          {
            amount: amount,
            stake-time: stacks-block-height,
            last-claim: stacks-block-height,
            total-rewards: u0
          }
        )
        (map-set pools
          { pool-id: pool-id }
          (merge pool-info { total-staked: (+ (get total-staked pool-info) amount) })
        )
        (let
          (
            (current-count (get-total-user-stakes tx-sender))
          )
          (map-set user-pool-count
            { user: tx-sender }
            { count: (+ current-count u1) }
          )
        )
        (ok true)
      )
      ERR-POOL-NOT-FOUND
    )
  )
)

(define-public (claim-rewards (pool-id uint))
  (begin
    (asserts! (not (var-get emergency-shutdown)) ERR-POOL-INACTIVE)
    (match (get-user-stake tx-sender pool-id)
      stake-info (begin
        (match (get-pool pool-id)
          pool-info (let
            (
              (blocks-elapsed (get-blocks-elapsed (get last-claim stake-info)))
              (rewards (calculate-rewards (get amount stake-info) (get reward-rate pool-info) blocks-elapsed))
            )
            (if (> rewards u0)
              (begin
                (try! (as-contract (stx-transfer? rewards tx-sender tx-sender)))
                (map-set user-stakes
                  { user: tx-sender, pool-id: pool-id }
                  (merge stake-info {
                    last-claim: stacks-block-height,
                    total-rewards: (+ (get total-rewards stake-info) rewards)
                  })
                )
                (ok rewards)
              )
              (ok u0)
            )
          )
          ERR-POOL-NOT-FOUND
        )
      )
      ERR-NOT-STAKED
    )
  )
)

(define-public (unstake (pool-id uint))
  (begin
    (match (get-user-stake tx-sender pool-id)
      stake-info (begin
        (match (get-pool pool-id)
          pool-info (let
            (
              (blocks-elapsed (get-blocks-elapsed (get last-claim stake-info)))
              (rewards (calculate-rewards (get amount stake-info) (get reward-rate pool-info) blocks-elapsed))
              (total-return (+ (get amount stake-info) rewards))
            )
            (try! (as-contract (stx-transfer? total-return tx-sender tx-sender)))
            (map-delete user-stakes { user: tx-sender, pool-id: pool-id })
            (map-set pools
              { pool-id: pool-id }
              (merge pool-info { total-staked: (- (get total-staked pool-info) (get amount stake-info)) })
            )
            (let
              (
                (current-count (get-total-user-stakes tx-sender))
              )
              (if (> current-count u1)
                (map-set user-pool-count
                  { user: tx-sender }
                  { count: (- current-count u1) }
                )
                (map-delete user-pool-count { user: tx-sender })
              )
            )
            (ok { amount: (get amount stake-info), rewards: rewards })
          )
          ERR-POOL-NOT-FOUND
        )
      )
      ERR-NOT-STAKED
    )
  )
)

(define-public (toggle-pool (pool-id uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (match (get-pool pool-id)
      pool-info (begin
        (map-set pools
          { pool-id: pool-id }
          (merge pool-info { active: (not (get active pool-info)) })
        )
        (ok (not (get active pool-info)))
      )
      ERR-POOL-NOT-FOUND
    )
  )
)

(define-public (emergency-stop)
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (var-set emergency-shutdown true)
    (ok true)
  )
)

(define-public (resume-operations)
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (var-set emergency-shutdown false)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (fund-contract)
  (stx-transfer? u1000000 tx-sender (as-contract tx-sender))
)
