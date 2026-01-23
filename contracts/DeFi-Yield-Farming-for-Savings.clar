(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-POOL-NOT-FOUND (err u3))
(define-constant ERR-ALREADY-STAKED (err u4))
(define-constant ERR-NOT-STAKED (err u5))
(define-constant ERR-INVALID-AMOUNT (err u6))
(define-constant ERR-COOLDOWN-ACTIVE (err u7))
(define-constant ERR-POOL-INACTIVE (err u8))
(define-constant ERR-MULTIPLIER-NOT-FOUND (err u9))
(define-constant ERR-TOTAL-CAP-EXCEEDED (err u10))
(define-constant ERR-PER-USER-CAP-EXCEEDED (err u11))
(define-constant ERR-SELF-REFERRAL (err u12))
(define-constant ERR-ALREADY-REFERRED (err u13))
(define-constant ERR-NO-REFERRER (err u14))

(define-constant MULTIPLIER-BASE u10000)
(define-constant TIER-1-BLOCKS u1440)
(define-constant TIER-2-BLOCKS u4320)
(define-constant TIER-3-BLOCKS u8640)
(define-constant TIER-1-MULTIPLIER u11000)
(define-constant TIER-2-MULTIPLIER u12500)
(define-constant TIER-3-MULTIPLIER u15000)
(define-constant REFERRAL-BONUS-PERCENT u500)
(define-constant REFEREE-BONUS-PERCENT u300)

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

(define-map pool-limits
  { pool-id: uint }
  {
    max-total: (optional uint),
    max-per-user: (optional uint)
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

(define-map user-multipliers
  { user: principal, pool-id: uint }
  {
    current-tier: uint,
    last-tier-update: uint,
    accumulated-multiplier: uint
  }
)

(define-map referrals
  { user: principal }
  { referrer: principal }
)

(define-map referral-stats
  { user: principal }
  {
    total-referrals: uint,
    total-bonus-earned: uint
  }
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

(define-private (get-multiplier-tier (blocks-staked uint))
  (if (>= blocks-staked TIER-3-BLOCKS)
    u3
    (if (>= blocks-staked TIER-2-BLOCKS)
      u2
      (if (>= blocks-staked TIER-1-BLOCKS)
        u1
        u0
      )
    )
  )
)

(define-private (get-tier-multiplier (tier uint))
  (if (is-eq tier u3)
    TIER-3-MULTIPLIER
    (if (is-eq tier u2)
      TIER-2-MULTIPLIER
      (if (is-eq tier u1)
        TIER-1-MULTIPLIER
        MULTIPLIER-BASE
      )
    )
  )
)

(define-private (calculate-multiplied-rewards (base-rewards uint) (multiplier uint))
  (/ (* base-rewards multiplier) MULTIPLIER-BASE)
)

(define-private (get-user-multiplier (user principal) (pool-id uint))
  (map-get? user-multipliers { user: user, pool-id: pool-id })
)

(define-read-only (get-pool-info (pool-id uint))
  (get-pool pool-id)
)

(define-read-only (get-pool-limits (pool-id uint))
  (map-get? pool-limits { pool-id: pool-id })
)

(define-read-only (get-user-stake-info (user principal) (pool-id uint))
  (get-user-stake user pool-id)
)

(define-read-only (get-pending-rewards (user principal) (pool-id uint))
  (match (get-user-stake user pool-id)
    stake-info (let
      (
        (blocks-since-claim (get-blocks-elapsed (get last-claim stake-info)))
        (blocks-staked (get-blocks-elapsed (get stake-time stake-info)))
        (amount (get amount stake-info))
        (current-tier (get-multiplier-tier blocks-staked))
        (multiplier (get-tier-multiplier current-tier))
      )
      (match (get-pool pool-id)
        pool-info (let
          (
            (base-rewards (calculate-rewards amount (get reward-rate pool-info) blocks-since-claim))
          )
          (ok (calculate-multiplied-rewards base-rewards multiplier))
        )
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

(define-read-only (get-user-multiplier-info (user principal) (pool-id uint))
  (get-user-multiplier user pool-id)
)

(define-read-only (get-current-multiplier (user principal) (pool-id uint))
  (match (get-user-stake user pool-id)
    stake-info (let
      (
        (blocks-staked (get-blocks-elapsed (get stake-time stake-info)))
        (current-tier (get-multiplier-tier blocks-staked))
      )
      (ok (get-tier-multiplier current-tier))
    )
    (err ERR-NOT-STAKED)
  )
)

(define-read-only (get-multiplier-tiers)
  {
    base-multiplier: MULTIPLIER-BASE,
    tier-1: { blocks: TIER-1-BLOCKS, multiplier: TIER-1-MULTIPLIER },
    tier-2: { blocks: TIER-2-BLOCKS, multiplier: TIER-2-MULTIPLIER },
    tier-3: { blocks: TIER-3-BLOCKS, multiplier: TIER-3-MULTIPLIER }
  }
)

(define-read-only (get-referrer (user principal))
  (map-get? referrals { user: user })
)

(define-read-only (get-referral-stats (user principal))
  (default-to 
    { total-referrals: u0, total-bonus-earned: u0 }
    (map-get? referral-stats { user: user })
  )
)

(define-read-only (get-referral-bonus-rates)
  {
    referrer-bonus: REFERRAL-BONUS-PERCENT,
    referee-bonus: REFEREE-BONUS-PERCENT
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
        (match (map-get? pool-limits { pool-id: pool-id })
          limits (begin
            (match (get max-total limits)
              mt (begin (asserts! (<= (+ (get total-staked pool-info) amount) mt) ERR-TOTAL-CAP-EXCEEDED) true)
              true
            )
            (match (get max-per-user limits)
              mp (begin (asserts! (<= amount mp) ERR-PER-USER-CAP-EXCEEDED) true)
              true
            )
            true
          )
          true
        )
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
        (map-set user-multipliers
          { user: tx-sender, pool-id: pool-id }
          {
            current-tier: u0,
            last-tier-update: stacks-block-height,
            accumulated-multiplier: MULTIPLIER-BASE
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
              (blocks-staked (get-blocks-elapsed (get stake-time stake-info)))
              (current-tier (get-multiplier-tier blocks-staked))
              (multiplier (get-tier-multiplier current-tier))
              (base-rewards (calculate-rewards (get amount stake-info) (get reward-rate pool-info) blocks-elapsed))
              (rewards (calculate-multiplied-rewards base-rewards multiplier))
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
                (map-set user-multipliers
                  { user: tx-sender, pool-id: pool-id }
                  {
                    current-tier: current-tier,
                    last-tier-update: stacks-block-height,
                    accumulated-multiplier: multiplier
                  }
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
              (blocks-staked (get-blocks-elapsed (get stake-time stake-info)))
              (current-tier (get-multiplier-tier blocks-staked))
              (multiplier (get-tier-multiplier current-tier))
              (base-rewards (calculate-rewards (get amount stake-info) (get reward-rate pool-info) blocks-elapsed))
              (rewards (calculate-multiplied-rewards base-rewards multiplier))
              (total-return (+ (get amount stake-info) rewards))
            )
            (try! (as-contract (stx-transfer? total-return tx-sender tx-sender)))
            (map-delete user-stakes { user: tx-sender, pool-id: pool-id })
            (map-delete user-multipliers { user: tx-sender, pool-id: pool-id })
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

(define-public (set-pool-limits (pool-id uint) (max-total (optional uint)) (max-per-user (optional uint)))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (match (get-pool pool-id)
      pool-info (begin
        (map-set pool-limits { pool-id: pool-id } { max-total: max-total, max-per-user: max-per-user })
        (ok true)
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

(define-public (register-referral (referrer principal))
  (begin
    (asserts! (not (is-eq tx-sender referrer)) ERR-SELF-REFERRAL)
    (asserts! (is-none (map-get? referrals { user: tx-sender })) ERR-ALREADY-REFERRED)
    (map-set referrals { user: tx-sender } { referrer: referrer })
    (let
      (
        (current-stats (get-referral-stats referrer))
      )
      (map-set referral-stats
        { user: referrer }
        {
          total-referrals: (+ (get total-referrals current-stats) u1),
          total-bonus-earned: (get total-bonus-earned current-stats)
        }
      )
    )
    (ok true)
  )
)

(define-public (claim-referral-bonus (pool-id uint))
  (begin
    (asserts! (not (var-get emergency-shutdown)) ERR-POOL-INACTIVE)
    (match (get-user-stake tx-sender pool-id)
      stake-info (match (map-get? referrals { user: tx-sender })
        ref-info (match (get-pool pool-id)
          pool-info (let
            (
              (blocks-elapsed (get-blocks-elapsed (get last-claim stake-info)))
              (base-rewards (calculate-rewards (get amount stake-info) (get reward-rate pool-info) blocks-elapsed))
              (referee-bonus (/ (* base-rewards REFEREE-BONUS-PERCENT) MULTIPLIER-BASE))
              (referrer-bonus (/ (* base-rewards REFERRAL-BONUS-PERCENT) MULTIPLIER-BASE))
              (referrer (get referrer ref-info))
              (referrer-stats (get-referral-stats referrer))
            )
            (if (> referee-bonus u0)
              (begin
                (try! (as-contract (stx-transfer? referee-bonus tx-sender tx-sender)))
                (if (> referrer-bonus u0)
                  (begin
                    (try! (as-contract (stx-transfer? referrer-bonus tx-sender referrer)))
                    (map-set referral-stats
                      { user: referrer }
                      {
                        total-referrals: (get total-referrals referrer-stats),
                        total-bonus-earned: (+ (get total-bonus-earned referrer-stats) referrer-bonus)
                      }
                    )
                    true
                  )
                  true
                )
                (ok { referee-bonus: referee-bonus, referrer-bonus: referrer-bonus })
              )
              (ok { referee-bonus: u0, referrer-bonus: u0 })
            )
          )
          ERR-POOL-NOT-FOUND
        )
        ERR-NO-REFERRER
      )
      ERR-NOT-STAKED
    )
  )
)
