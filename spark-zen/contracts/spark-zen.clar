;; SparkZen - Performance Rights Management Platform
;; Enhanced Creative Rights Tokens (CRT) with Performance DNA Protocol

;; ========================================
;; ERROR CONSTANTS
;; ========================================
(define-constant ERR-UNAUTHORIZED (err u1000))
(define-constant ERR-WORK-NOT-FOUND (err u1001))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1002))
(define-constant ERR-INVALID-PERFORMANCE (err u1003))
(define-constant ERR-WORK-INACTIVE (err u1004))
(define-constant ERR-RIGHTS-HOLDER-NOT-STAKED (err u1005))
(define-constant ERR-INSUFFICIENT-STAKE (err u1006))
(define-constant ERR-PERFORMANCE-DATA-INVALID (err u1007))
(define-constant ERR-THRESHOLD-NOT-MET (err u1008))
(define-constant ERR-LICENSING-EXPIRED (err u1009))
(define-constant ERR-ALREADY-LICENSED (err u1010))
(define-constant ERR-WORK-COMPLETED (err u1011))
(define-constant ERR-EMERGENCY-ACTIVE (err u1012))
(define-constant ERR-INVALID-PARAMETERS (err u1013))
(define-constant ERR-CONSENSUS-NOT-REACHED (err u1014))
(define-constant ERR-SLASHING-FAILED (err u1015))

;; ========================================
;; CONTRACT CONSTANTS
;; ========================================
(define-constant CONTRACT-OWNER tx-sender)
(define-constant DEPLOYER tx-sender)
(define-constant MINIMUM-STAKE u1000000) ;; 1 CRT minimum stake
(define-constant LICENSING-WINDOW u144) ;; ~24 hours in blocks
(define-constant MIN-RIGHTS-HOLDERS u3)
(define-constant MAX-RIGHTS-HOLDERS u10)
(define-constant PERFORMANCE-DNA-THRESHOLD u75) ;; 75% consensus required
(define-constant MAX-PERFORMANCES u20)
(define-constant SLASHING-PENALTY u25) ;; 25% of stake
(define-constant REPUTATION-DECAY u5) ;; 5 points per failed licensing
(define-constant MIN-REPUTATION u20)

;; Token economics constants
(define-constant TOKEN-PRECISION u1000000) ;; 6 decimal places
(define-constant BASE-CONVERSION-RATE u100) ;; 0.01% base rate
(define-constant BONUS-MULTIPLIER u150) ;; 50% bonus for high-performing categories

;; ========================================
;; FUNGIBLE TOKEN
;; ========================================
(define-fungible-token creative-rights-token)

;; ========================================
;; DATA VARIABLES
;; ========================================
(define-data-var total-works uint u0)
(define-data-var total-performances-verified uint u0)
(define-data-var dna-protocol-active bool true)
(define-data-var emergency-pause bool false)
(define-data-var platform-fee-rate uint u250) ;; 2.5%
(define-data-var treasury-balance uint u0)
(define-data-var governance-threshold uint u3) ;; Minimum governance participants

;; ========================================
;; DATA STRUCTURES
;; ========================================
(define-map creative-works
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    category: (string-ascii 50),
    target-amount: uint,
    raised-amount: uint,
    current-performance: uint,
    total-performances: uint,
    performance-scores: (list 20 uint), ;; Track performance history
    active: bool,
    completed: bool,
    dna-verified: bool,
    sensor-config: (string-ascii 100), ;; Enhanced sensor configuration
    creation-block: uint,
    completion-block: (optional uint),
    consensus-threshold: uint
  }
)

(define-map performance-milestones
  {work-id: uint, performance: uint}
  {
    description: (string-ascii 200),
    required-amount: uint,
    sensor-type: (string-ascii 30),
    target-value: uint,
    tolerance: uint, ;; Acceptable variance
    achieved: bool,
    achievement-block: (optional uint),
    verification-count: uint,
    consensus-score: uint,
    rewards-distributed: bool
  }
)

(define-map rights-holder-profiles
  principal
  {
    staked-amount: uint,
    available-stake: uint, ;; Unstaked portion
    active-licensings: uint,
    successful-licensings: uint,
    failed-licensings: uint,
    reputation-score: uint,
    specializations: (list 5 (string-ascii 30)),
    last-activity-block: uint,
    slashed-amount: uint,
    earnings: uint
  }
)

(define-map licensing-records
  {rights-holder: principal, work-id: uint, performance: uint}
  {
    validation-result: bool,
    confidence-score: uint, ;; 0-100 confidence in validation
    data-hash: (buff 32),
    submission-block: uint,
    stake-locked: uint,
    processed: bool,
    reward-earned: uint,
    notes: (string-ascii 200)
  }
)

(define-map investor-portfolios
  {investor: principal, work-id: uint}
  {
    total-invested: uint,
    crt-balance: uint,
    performance-rewards: uint,
    milestone-bonuses: uint,
    last-claim-block: uint,
    investment-blocks: (list 10 uint) ;; Investment history
  }
)

(define-map performance-data-registry
  (buff 32)
  {
    work-id: uint,
    performance-id: uint,
    sensor-readings: (list 5 uint), ;; Multiple sensor values
    metadata: (string-ascii 300),
    timestamp: uint,
    location-hash: (buff 32),
    submitter: principal,
    verification-status: (string-ascii 20),
    consensus-reached: bool
  }
)

(define-map governance-proposals
  uint
  {
    proposer: principal,
    proposal-type: (string-ascii 50),
    description: (string-ascii 500),
    target-value: uint,
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    executed: bool,
    min-stake-required: uint
  }
)

;; ========================================
;; HELPER FUNCTIONS
;; ========================================
(define-private (calculate-crt-tokens (amount uint) (category (string-ascii 50)) (performance-bonus uint))
  (let (
    (base-tokens (/ (* amount BASE-CONVERSION-RATE) TOKEN-PRECISION))
    (category-multiplier (if (or (is-eq category "music") (is-eq category "art")) 
                            BONUS-MULTIPLIER u100))
    (performance-multiplier (+ u100 performance-bonus))
    (final-tokens (/ (* base-tokens category-multiplier performance-multiplier) u10000))
  )
    final-tokens
  )
)

(define-private (calculate-reputation-adjustment (successful bool) (current-reputation uint))
  (if successful
    (if (> (+ current-reputation u10) u100) u100 (+ current-reputation u10)) ;; Max reputation is 100
    (if (< (- current-reputation REPUTATION-DECAY) MIN-REPUTATION) MIN-REPUTATION (- current-reputation REPUTATION-DECAY))
  )
)

(define-private (is-consensus-reached (work-id uint) (performance uint))
  (let (
    (milestone (unwrap! (map-get? performance-milestones {work-id: work-id, performance: performance}) false))
    (required-threshold PERFORMANCE-DNA-THRESHOLD)
  )
    (>= (get consensus-score milestone) required-threshold)
  )
)

(define-private (distribute-milestone-rewards (work-id uint) (performance uint))
  (let (
    (work (unwrap! (map-get? creative-works work-id) (err u2005)))
    (milestone (unwrap! (map-get? performance-milestones {work-id: work-id, performance: performance}) (err u2006)))
    (reward-pool (/ (get required-amount milestone) u10)) ;; 10% of milestone amount as rewards
  )
    ;; Implementation for reward distribution would go here
    (ok true)
  )
)

(define-private (slash-stake (rights-holder principal) (amount uint))
  (let (
    (profile (unwrap! (map-get? rights-holder-profiles rights-holder) false))
    (slash-amount (if (< amount (get staked-amount profile)) amount (get staked-amount profile)))
  )
    (map-set rights-holder-profiles rights-holder
      (merge profile {
        staked-amount: (- (get staked-amount profile) slash-amount),
        slashed-amount: (+ (get slashed-amount profile) slash-amount)
      })
    )
    (var-set treasury-balance (+ (var-get treasury-balance) slash-amount))
    true
  )
)

;; ========================================
;; OWNER/GOVERNANCE FUNCTIONS
;; ========================================
(define-public (set-platform-parameters (fee-rate uint) (min-stake uint) (threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= fee-rate u1000) ERR-INVALID-PARAMETERS) ;; Max 10%
    (asserts! (>= min-stake u100000) ERR-INVALID-PARAMETERS) ;; Min 0.1 CRT
    (asserts! (and (>= threshold u51) (<= threshold u100)) ERR-INVALID-PARAMETERS)
    
    (var-set platform-fee-rate fee-rate)
    ;; Update other parameters as needed
    (ok true)
  )
)

(define-public (emergency-pause-toggle)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (var-set emergency-pause (not (var-get emergency-pause))))
  )
)

(define-public (withdraw-treasury (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= amount (var-get treasury-balance)) ERR-INSUFFICIENT-FUNDS)
    
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    (try! (ft-transfer? creative-rights-token amount (as-contract tx-sender) recipient))
    (ok amount)
  )
)

;; ========================================
;; CORE PLATFORM FUNCTIONS
;; ========================================
(define-public (create-creative-work 
  (title (string-ascii 100))
  (category (string-ascii 50))
  (target-amount uint)
  (total-performances uint)
  (sensor-config (string-ascii 100))
  (consensus-threshold uint)
)
  (let (
    (work-id (+ (var-get total-works) u1))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (> target-amount u1000000) ERR-INVALID-PARAMETERS) ;; Min 1 STX
    (asserts! (and (> total-performances u0) (<= total-performances MAX-PERFORMANCES)) ERR-INVALID-PARAMETERS)
    (asserts! (and (>= consensus-threshold u51) (<= consensus-threshold u100)) ERR-INVALID-PARAMETERS)
    
    ;; Charge creation fee
    (try! (stx-transfer? u100000 tx-sender (as-contract tx-sender))) ;; 0.1 STX creation fee
    
    (map-set creative-works work-id
      {
        creator: tx-sender,
        title: title,
        category: category,
        target-amount: target-amount,
        raised-amount: u0,
        current-performance: u1,
        total-performances: total-performances,
        performance-scores: (list),
        active: true,
        completed: false,
        dna-verified: false,
        sensor-config: sensor-config,
        creation-block: block-height,
        completion-block: none,
        consensus-threshold: consensus-threshold
      }
    )
    
    (var-set total-works work-id)
    (ok work-id)
  )
)

(define-public (invest-in-creative-work (work-id uint) (amount uint))
  (let (
    (work (unwrap! (map-get? creative-works work-id) ERR-WORK-NOT-FOUND))
    (current-portfolio (default-to 
      {total-invested: u0, crt-balance: u0, performance-rewards: u0, 
       milestone-bonuses: u0, last-claim-block: u0, investment-blocks: (list)}
      (map-get? investor-portfolios {investor: tx-sender, work-id: work-id})
    ))
    (performance-bonus (if (> (get raised-amount work) (/ (get target-amount work) u2)) u20 u0))
    (crt-tokens (calculate-crt-tokens amount (get category work) performance-bonus))
    (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000))
    (net-investment (- amount platform-fee))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (get active work) ERR-WORK-INACTIVE)
    (asserts! (not (get completed work)) ERR-WORK-COMPLETED)
    (asserts! (>= amount u10000) ERR-INVALID-PARAMETERS) ;; Min 0.01 STX
    
    ;; Transfer STX and handle fees
    (try! (stx-transfer? net-investment tx-sender (as-contract tx-sender)))
    (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
    
    ;; Mint CRT tokens
    (try! (ft-mint? creative-rights-token crt-tokens tx-sender))
    
    ;; Update work funding
    (map-set creative-works work-id
      (merge work {raised-amount: (+ (get raised-amount work) net-investment)})
    )
    
    ;; Update investor portfolio
    (map-set investor-portfolios {investor: tx-sender, work-id: work-id}
      (merge current-portfolio {
        total-invested: (+ (get total-invested current-portfolio) net-investment),
        crt-balance: (+ (get crt-balance current-portfolio) crt-tokens),
        investment-blocks: (match (as-max-len? 
          (append (get investment-blocks current-portfolio) block-height) u10)
          success success
          (get investment-blocks current-portfolio))
      })
    )
    
    (ok crt-tokens)
  )
)

(define-public (register-as-rights-holder (stake-amount uint) (specializations (list 5 (string-ascii 30))))
  (let (
    (current-profile (default-to 
      {staked-amount: u0, available-stake: u0, active-licensings: u0, successful-licensings: u0,
       failed-licensings: u0, reputation-score: u100, specializations: (list), 
       last-activity-block: u0, slashed-amount: u0, earnings: u0}
      (map-get? rights-holder-profiles tx-sender)
    ))
  )
    (asserts! (>= stake-amount MINIMUM-STAKE) ERR-INSUFFICIENT-STAKE)
    (asserts! (>= (ft-get-balance creative-rights-token tx-sender) stake-amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> (len specializations) u0) ERR-INVALID-PARAMETERS)
    
    ;; Lock tokens for staking
    (try! (ft-transfer? creative-rights-token stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set rights-holder-profiles tx-sender
      (merge current-profile {
        staked-amount: (+ (get staked-amount current-profile) stake-amount),
        available-stake: stake-amount,
        specializations: specializations,
        last-activity-block: block-height
      })
    )
    
    (ok true)
  )
)

(define-public (submit-performance-validation 
  (work-id uint) 
  (performance uint) 
  (validation-result bool)
  (confidence-score uint)
  (data-hash (buff 32))
  (notes (string-ascii 200))
)
  (let (
    (rights-holder-profile (unwrap! (map-get? rights-holder-profiles tx-sender) ERR-RIGHTS-HOLDER-NOT-STAKED))
    (work (unwrap! (map-get? creative-works work-id) ERR-WORK-NOT-FOUND))
    (milestone (unwrap! (map-get? performance-milestones {work-id: work-id, performance: performance}) ERR-INVALID-PERFORMANCE))
    (validation-key {rights-holder: tx-sender, work-id: work-id, performance: performance})
    (stake-to-lock (/ (get staked-amount rights-holder-profile) u4)) ;; Lock 25% of stake
  )
    (asserts! (get active work) ERR-WORK-INACTIVE)
    (asserts! (is-eq (get current-performance work) performance) ERR-INVALID-PERFORMANCE)
    (asserts! (>= (get reputation-score rights-holder-profile) MIN-REPUTATION) (err u2000))
    (asserts! (and (>= confidence-score u1) (<= confidence-score u100)) ERR-INVALID-PARAMETERS)
    (asserts! (>= (get available-stake rights-holder-profile) stake-to-lock) ERR-INSUFFICIENT-STAKE)
    (asserts! (is-none (map-get? licensing-records validation-key)) ERR-ALREADY-LICENSED)
    
    ;; Record the validation
    (map-set licensing-records validation-key
      {
        validation-result: validation-result,
        confidence-score: confidence-score,
        data-hash: data-hash,
        submission-block: block-height,
        stake-locked: stake-to-lock,
        processed: false,
        reward-earned: u0,
        notes: notes
      }
    )
    
    ;; Update rights holder stats
    (map-set rights-holder-profiles tx-sender
      (merge rights-holder-profile {
        active-licensings: (+ (get active-licensings rights-holder-profile) u1),
        available-stake: (- (get available-stake rights-holder-profile) stake-to-lock),
        last-activity-block: block-height
      })
    )
    
    ;; Update milestone verification count
    (map-set performance-milestones {work-id: work-id, performance: performance}
      (merge milestone {
        verification-count: (+ (get verification-count milestone) u1)
      })
    )
    
    (ok true)
  )
)

(define-public (finalize-performance-consensus (work-id uint) (performance uint))
  (let (
    (work (unwrap! (map-get? creative-works work-id) ERR-WORK-NOT-FOUND))
    (milestone (unwrap! (map-get? performance-milestones {work-id: work-id, performance: performance}) ERR-INVALID-PERFORMANCE))
  )
    (asserts! (>= (get verification-count milestone) MIN-RIGHTS-HOLDERS) ERR-THRESHOLD-NOT-MET)
    (asserts! (is-consensus-reached work-id performance) ERR-CONSENSUS-NOT-REACHED)
    (asserts! (not (get achieved milestone)) (err u2001))
    
    ;; Mark milestone as achieved
    (map-set performance-milestones {work-id: work-id, performance: performance}
      (merge milestone {
        achieved: true,
        achievement-block: (some block-height)
      })
    )
    
    ;; Update work progress
    (if (< (get current-performance work) (get total-performances work))
      (map-set creative-works work-id
        (merge work {current-performance: (+ (get current-performance work) u1)})
      )
      (map-set creative-works work-id
        (merge work {
          completed: true,
          completion-block: (some block-height)
        })
      )
    )
    
    ;; Distribute rewards (implementation would process all validators)
    (try! (distribute-milestone-rewards work-id performance))
    (var-set total-performances-verified (+ (var-get total-performances-verified) u1))
    
    (ok true)
  )
)

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================
(define-read-only (get-creative-work-details (work-id uint))
  (map-get? creative-works work-id)
)

(define-read-only (get-performance-milestone-info (work-id uint) (performance uint))
  (map-get? performance-milestones {work-id: work-id, performance: performance})
)

(define-read-only (get-rights-holder-profile (rights-holder principal))
  (map-get? rights-holder-profiles rights-holder)
)

(define-read-only (get-investor-portfolio (investor principal) (work-id uint))
  (map-get? investor-portfolios {investor: investor, work-id: work-id})
)

(define-read-only (get-validation-record (rights-holder principal) (work-id uint) (performance uint))
  (map-get? licensing-records {rights-holder: rights-holder, work-id: work-id, performance: performance})
)

(define-read-only (get-platform-statistics)
  {
    total-works: (var-get total-works),
    total-verified-performances: (var-get total-performances-verified),
    treasury-balance: (var-get treasury-balance),
    platform-fee-rate: (var-get platform-fee-rate),
    emergency-paused: (var-get emergency-pause),
    dna-protocol-active: (var-get dna-protocol-active)
  }
)

(define-read-only (calculate-investment-tokens (amount uint) (category (string-ascii 50)) (performance-bonus uint))
  (calculate-crt-tokens amount category performance-bonus)
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance creative-rights-token user)
)

(define-read-only (get-work-funding-progress (work-id uint))
  (match (map-get? creative-works work-id)
    work (some {
      target: (get target-amount work),
      raised: (get raised-amount work),
      percentage: (/ (* (get raised-amount work) u100) (get target-amount work)),
      completed: (get completed work)
    })
    none
  )
)