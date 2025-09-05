;; SparkZen - Performance Rights Management Platform
;; Creative Rights Tokens (CRT) with Performance DNA Protocol

;; Error Constants
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

;; Contract Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MINIMUM-STAKE u1000000) ;; 1 CRT token minimum stake
(define-constant LICENSING-WINDOW u144) ;; ~24 hours in blocks
(define-constant MIN-RIGHTS-HOLDERS u3)
(define-constant PERFORMANCE-DNA-THRESHOLD u75) ;; 75% accuracy threshold

;; Fungible Token Definition
(define-fungible-token creative-rights-token)

;; Data Variables
(define-data-var total-works uint u0)
(define-data-var total-performance-verified uint u0)
(define-data-var dna-protocol-active bool true)
(define-data-var emergency-pause bool false)
(define-data-var platform-fee-rate uint u250) ;; 2.5%

;; Data Maps
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
    originality-score: uint,
    collaboration-diversity: uint,
    commercial-viability: uint,
    active: bool,
    completed: bool,
    dna-verified: bool,
    sensor-address: (string-ascii 64),
    creation-block: uint
  }
)

(define-map performance-milestones
  {work-id: uint, performance: uint}
  {
    description: (string-ascii 200),
    licensing-amount: uint,
    threshold-value: uint,
    sensor-type: (string-ascii 30),
    verification-data: (string-ascii 500),
    achieved: bool,
    verification-block: uint,
    rights-holder-count: uint
  }
)

(define-map rights-holder-stakes
  principal
  {
    staked-amount: uint,
    active-licensings: uint,
    successful-licensings: uint,
    failed-licensings: uint,
    reputation-score: uint,
    last-licensing-block: uint
  }
)

(define-map licensing-validations
  {rights-holder: principal, work-id: uint, performance: uint}
  {
    licensing-result: bool,
    performance-data-hash: (buff 32),
    licensing-block: uint,
    stake-amount: uint,
    processed: bool
  }
)

(define-map user-investments
  {user: principal, work-id: uint}
  {
    total-invested: uint,
    token-balance: uint,
    originality-earned: uint,
    collaboration-earned: uint,
    viability-earned: uint,
    last-investment-block: uint
  }
)

(define-map performance-data-registry
  (buff 32)
  {
    work-id: uint,
    performance: uint,
    sensor-reading: uint,
    timestamp: uint,
    location-hash: (buff 32),
    verified: bool,
    verification-count: uint
  }
)

(define-map collaborative-connections
  {user1: principal, user2: principal}
  {
    shared-works: uint,
    connection-strength: uint,
    collaborative-royalties: uint,
    last-interaction: uint
  }
)

;; Helper Functions
(define-private (calculate-crt-tokens (amount uint) (category (string-ascii 50)))
  ;; Simple token calculation - could be enhanced with category-based multipliers
  (/ (* amount u100) u1000000) ;; 0.01% conversion rate
)

;; Owner Functions
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= new-rate u1000) (err u2000)) ;; Max 10% fee
    (ok (var-set platform-fee-rate new-rate))
  )
)

(define-public (toggle-emergency-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (var-set emergency-pause (not (var-get emergency-pause))))
  )
)

(define-public (set-dna-protocol-status (active bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (var-set dna-protocol-active active))
  )
)

;; Public Functions
(define-public (create-creative-work 
  (title (string-ascii 100))
  (category (string-ascii 50))
  (target-amount uint)
  (total-performances uint)
  (sensor-address (string-ascii 64))
)
  (let (
    (work-id (+ (var-get total-works) u1))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (> target-amount u0) (err u2001))
    (asserts! (> total-performances u0) (err u2002))
    (asserts! (<= total-performances u10) (err u2003))
    
    (map-set creative-works work-id
      {
        creator: tx-sender,
        title: title,
        category: category,
        target-amount: target-amount,
        raised-amount: u0,
        current-performance: u1,
        total-performances: total-performances,
        originality-score: u0,
        collaboration-diversity: u0,
        commercial-viability: u0,
        active: true,
        completed: false,
        dna-verified: false,
        sensor-address: sensor-address,
        creation-block: block-height
      }
    )
    
    (var-set total-works work-id)
    (ok work-id)
  )
)

(define-public (invest-in-work (work-id uint) (amount uint))
  (let (
    (work (unwrap! (map-get? creative-works work-id) ERR-WORK-NOT-FOUND))
    (current-investment (default-to 
      {total-invested: u0, token-balance: u0, originality-earned: u0, 
       collaboration-earned: u0, viability-earned: u0, last-investment-block: u0}
      (map-get? user-investments {user: tx-sender, work-id: work-id})
    ))
    (crt-tokens (calculate-crt-tokens amount (get category work)))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (get active work) ERR-WORK-INACTIVE)
    (asserts! (not (get completed work)) ERR-WORK-COMPLETED)
    (asserts! (> amount u0) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Mint CRT tokens to investor
    (try! (ft-mint? creative-rights-token crt-tokens tx-sender))
    
    ;; Update work
    (map-set creative-works work-id
      (merge work {raised-amount: (+ (get raised-amount work) amount)})
    )
    
    ;; Update user investment
    (map-set user-investments {user: tx-sender, work-id: work-id}
      (merge current-investment {
        total-invested: (+ (get total-invested current-investment) amount),
        token-balance: (+ (get token-balance current-investment) crt-tokens),
        last-investment-block: block-height
      })
    )
    
    (ok crt-tokens)
  )
)

(define-public (stake-for-licensing (stake-amount uint))
  (let (
    (current-stake (default-to 
      {staked-amount: u0, active-licensings: u0, successful-licensings: u0,
       failed-licensings: u0, reputation-score: u100, last-licensing-block: u0}
      (map-get? rights-holder-stakes tx-sender)
    ))
  )
    (asserts! (>= stake-amount MINIMUM-STAKE) ERR-INSUFFICIENT-STAKE)
    (asserts! (>= (ft-get-balance creative-rights-token tx-sender) stake-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Lock tokens for staking
    (try! (ft-transfer? creative-rights-token stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set rights-holder-stakes tx-sender
      (merge current-stake {
        staked-amount: (+ (get staked-amount current-stake) stake-amount)
      })
    )
    
    (ok true)
  )
)

(define-public (submit-performance-data 
  (work-id uint) 
  (performance uint) 
  (sensor-reading uint) 
  (location-hash (buff 32))
  (data-hash (buff 32))
)
  (let (
    (work (unwrap! (map-get? creative-works work-id) ERR-WORK-NOT-FOUND))
    (performance-data (unwrap! (map-get? performance-milestones {work-id: work-id, performance: performance}) ERR-INVALID-PERFORMANCE))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (get active work) ERR-WORK-INACTIVE)
    (asserts! (is-eq (get current-performance work) performance) ERR-INVALID-PERFORMANCE)
    (asserts! (var-get dna-protocol-active) (err u2004))
    
    (map-set performance-data-registry data-hash
      {
        work-id: work-id,
        performance: performance,
        sensor-reading: sensor-reading,
        timestamp: block-height,
        location-hash: location-hash,
        verified: false,
        verification-count: u0
      }
    )
    
    (ok data-hash)
  )
)

(define-public (license-performance 
  (work-id uint) 
  (performance uint) 
  (licensing-result bool) 
  (performance-data-hash (buff 32))
)
  (let (
    (rights-holder-stake (unwrap! (map-get? rights-holder-stakes tx-sender) ERR-RIGHTS-HOLDER-NOT-STAKED))
    (work (unwrap! (map-get? creative-works work-id) ERR-WORK-NOT-FOUND))
    (performance-data (unwrap! (map-get? performance-data-registry performance-data-hash) ERR-PERFORMANCE-DATA-INVALID))
    (licensing-key {rights-holder: tx-sender, work-id: work-id, performance: performance})
    (existing-licensing (map-get? licensing-validations licensing-key))
  )
    (asserts! (> (get staked-amount rights-holder-stake) u0) ERR-INSUFFICIENT-STAKE)
    (asserts! (get active work) ERR-WORK-INACTIVE)
    (asserts! (is-eq (get current-performance work) performance) ERR-INVALID-PERFORMANCE)
    (asserts! (is-none existing-licensing) ERR-ALREADY-LICENSED)
    (asserts! (< (- block-height (get timestamp performance-data)) LICENSING-WINDOW) ERR-LICENSING-EXPIRED)
    
    ;; Record licensing
    (map-set licensing-validations licensing-key
      {
        licensing-result: licensing-result,
        performance-data-hash: performance-data-hash,
        licensing-block: block-height,
        stake-amount: (get staked-amount rights-holder-stake),
        processed: false
      }
    )
    
    ;; Update rights holder stats
    (map-set rights-holder-stakes tx-sender
      (merge rights-holder-stake {
        active-licensings: (+ (get active-licensings rights-holder-stake) u1),
        last-licensing-block: block-height
      })
    )
    
    ;; Update performance data verification count
    (map-set performance-data-registry performance-data-hash
      (merge performance-data {
        verification-count: (+ (get verification-count performance-data) u1)
      })
    )
    
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-creative-work (work-id uint))
  (map-get? creative-works work-id)
)

(define-read-only (get-performance-milestone (work-id uint) (performance uint))
  (map-get? performance-milestones {work-id: work-id, performance: performance})
)

(define-read-only (get-rights-holder-stake (rights-holder principal))
  (map-get? rights-holder-stakes rights-holder)
)

(define-read-only (get-user-investment (user principal) (work-id uint))
  (map-get? user-investments {user: user, work-id: work-id})
)

(define-read-only (get-performance-data (data-hash (buff 32)))
  (map-get? performance-data-registry data-hash)
)

(define-read-only (get-total-works)
  (var-get total-works)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (is-emergency-paused)
  (var-get emergency-pause)
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance creative-rights-token user)
)