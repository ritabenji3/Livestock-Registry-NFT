;; Livestock Insurance & Claims Management System
;; Enables insurance coverage for registered livestock with claims processing

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_INVALID_DATA (err u402))
(define-constant ERR_POLICY_EXPIRED (err u403))
(define-constant ERR_CLAIM_ALREADY_EXISTS (err u404))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u405))
(define-constant ERR_POLICY_NOT_ACTIVE (err u406))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u407))

(define-data-var last-policy-id uint u0)
(define-data-var last-claim-id uint u0)
(define-data-var last-provider-id uint u0)

;; Insurance provider registry
(define-map insurance-providers
  uint ;; provider-id
  {
    name: (string-ascii 64),
    license-number: (string-ascii 32),
    contact-info: (string-ascii 128),
    rating: uint, ;; 1-100
    total-policies: uint,
    total-claims-paid: uint,
    is-active: bool,
    registered-by: principal,
    registered-at: uint
  }
)

;; Insurance policy types and coverage
(define-map policy-templates
  {provider-id: uint, template-id: uint}
  {
    policy-name: (string-ascii 64),
    species-covered: (string-ascii 32),
    coverage-types: (list 5 (string-ascii 32)), ;; MORTALITY, VETERINARY, THEFT, DISEASE
    premium-per-month-cents: uint,
    max-coverage-amount-cents: uint,
    deductible-cents: uint,
    age-restrictions: (string-ascii 64),
    breed-restrictions: (string-ascii 128),
    is-available: bool,
    created-at: uint
  }
)

;; Active insurance policies for animals
(define-map animal-policies
  uint ;; policy-id
  {
    animal-id: uint,
    provider-id: uint,
    template-id: uint,
    policy-holder: principal,
    coverage-amount-cents: uint,
    monthly-premium-cents: uint,
    deductible-cents: uint,
    policy-start-date: uint,
    policy-end-date: uint,
    premium-due-date: uint,
    is-active: bool,
    total-premiums-paid: uint,
    claims-count: uint,
    total-claims-amount: uint
  }
)

;; Insurance claims tracking
(define-map insurance-claims
  uint ;; claim-id
  {
    policy-id: uint,
    animal-id: uint,
    claimant: principal,
    claim-type: (string-ascii 32), ;; MORTALITY, VETERINARY, THEFT, DISEASE, ACCIDENT
    claim-amount-cents: uint,
    incident-date: uint,
    incident-description: (string-ascii 256),
    veterinary-report: (optional (string-ascii 256)),
    supporting-documents: (optional (string-ascii 128)),
    claim-status: (string-ascii 16), ;; PENDING, APPROVED, DENIED, PAID
    assessor-notes: (optional (string-ascii 256)),
    approved-amount-cents: uint,
    submitted-at: uint,
    processed-at: (optional uint),
    processed-by: (optional principal)
  }
)

;; Premium payment tracking
(define-map premium-payments
  {policy-id: uint, payment-date: uint}
  {
    amount-paid-cents: uint,
    payment-method: (string-ascii 16), ;; STX, DEBIT_AUTO
    paid-by: principal,
    payment-for-month: uint,
    late-fee-cents: uint,
    transaction-id: (optional (string-ascii 64))
  }
)

;; Risk assessment data
(define-map animal-risk-profiles
  uint ;; animal-id
  {
    risk-score: uint, ;; 1-100 (higher = riskier)
    health-history-score: uint, ;; 1-100
    breed-risk-factor: uint, ;; 1-100
    age-risk-factor: uint, ;; 1-100
    farm-location-risk: uint, ;; 1-100
    previous-claims: uint,
    last-assessment-date: uint,
    assessed-by: principal
  }
)

;; Authorized insurance assessors
(define-map authorized-assessors principal bool)

;; Read-only functions
(define-read-only (get-insurance-provider (provider-id uint))
  (map-get? insurance-providers provider-id)
)

(define-read-only (get-policy-template (provider-id uint) (template-id uint))
  (map-get? policy-templates {provider-id: provider-id, template-id: template-id})
)

(define-read-only (get-animal-policy (policy-id uint))
  (map-get? animal-policies policy-id)
)

(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (get-animal-risk-profile (animal-id uint))
  (map-get? animal-risk-profiles animal-id)
)

(define-read-only (is-authorized-assessor (assessor principal))
  (default-to false (map-get? authorized-assessors assessor))
)

;; Check if animal has active insurance
(define-read-only (has-active-insurance (animal-id uint))
  (ok false) ;; Simplified - would need to iterate through policies
)

;; Calculate premium based on risk factors
(define-read-only (calculate-premium (animal-id uint) (base-premium uint))
  (let
    (
      (risk-profile (map-get? animal-risk-profiles animal-id))
    )
    (match risk-profile
      profile (ok (+ base-premium (/ (* base-premium (get risk-score profile)) u100)))
      (ok base-premium)
    )
  )
)

;; Admin functions
(define-public (authorize-assessor (assessor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-assessors assessor true))
  )
)

(define-public (register-insurance-provider
  (name (string-ascii 64))
  (license-number (string-ascii 32))
  (contact-info (string-ascii 128))
)
  (let
    (
      (provider-id (+ (var-get last-provider-id) u1))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_DATA)
    (asserts! (> (len license-number) u0) ERR_INVALID_DATA)
    
    (map-set insurance-providers provider-id
      {
        name: name,
        license-number: license-number,
        contact-info: contact-info,
        rating: u75,
        total-policies: u0,
        total-claims-paid: u0,
        is-active: true,
        registered-by: tx-sender,
        registered-at: current-block
      }
    )
    
    (var-set last-provider-id provider-id)
    (ok provider-id)
  )
)

;; Create policy template
(define-public (create-policy-template
  (provider-id uint)
  (template-id uint)
  (policy-name (string-ascii 64))
  (species-covered (string-ascii 32))
  (coverage-types (list 5 (string-ascii 32)))
  (premium-per-month-cents uint)
  (max-coverage-amount-cents uint)
  (deductible-cents uint)
  (age-restrictions (string-ascii 64))
  (breed-restrictions (string-ascii 128))
)
  (let
    ((current-block stacks-block-height))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? insurance-providers provider-id)) ERR_NOT_FOUND)
    (asserts! (> premium-per-month-cents u0) ERR_INVALID_DATA)
    (asserts! (> max-coverage-amount-cents u0) ERR_INVALID_DATA)
    
    (map-set policy-templates
      {provider-id: provider-id, template-id: template-id}
      {
        policy-name: policy-name,
        species-covered: species-covered,
        coverage-types: coverage-types,
        premium-per-month-cents: premium-per-month-cents,
        max-coverage-amount-cents: max-coverage-amount-cents,
        deductible-cents: deductible-cents,
        age-restrictions: age-restrictions,
        breed-restrictions: breed-restrictions,
        is-available: true,
        created-at: current-block
      }
    )
    (ok true)
  )
)

;; Purchase insurance policy
(define-public (purchase-policy
  (animal-id uint)
  (provider-id uint)
  (template-id uint)
  (coverage-amount-cents uint)
  (policy-duration-months uint)
)
  (let
    (
      (policy-id (+ (var-get last-policy-id) u1))
      (current-block stacks-block-height)
      (template (unwrap! (map-get? policy-templates {provider-id: provider-id, template-id: template-id}) ERR_NOT_FOUND))
    )
    (asserts! (get is-available template) ERR_NOT_FOUND)
    (asserts! (<= coverage-amount-cents (get max-coverage-amount-cents template)) ERR_INSUFFICIENT_COVERAGE)
    (asserts! (> policy-duration-months u0) ERR_INVALID_DATA)
    
    (map-set animal-policies policy-id
      {
        animal-id: animal-id,
        provider-id: provider-id,
        template-id: template-id,
        policy-holder: tx-sender,
        coverage-amount-cents: coverage-amount-cents,
        monthly-premium-cents: (get premium-per-month-cents template),
        deductible-cents: (get deductible-cents template),
        policy-start-date: current-block,
        policy-end-date: (+ current-block (* policy-duration-months u4320)), ;; ~30 days per month
        premium-due-date: (+ current-block u4320),
        is-active: true,
        total-premiums-paid: u0,
        claims-count: u0,
        total-claims-amount: u0
      }
    )
    
    (var-set last-policy-id policy-id)
    (ok policy-id)
  )
)

;; Submit insurance claim
(define-public (submit-claim
  (policy-id uint)
  (claim-type (string-ascii 32))
  (claim-amount-cents uint)
  (incident-date uint)
  (incident-description (string-ascii 256))
  (veterinary-report (optional (string-ascii 256)))
)
  (let
    (
      (claim-id (+ (var-get last-claim-id) u1))
      (policy (unwrap! (map-get? animal-policies policy-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get policy-holder policy) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active policy) ERR_POLICY_NOT_ACTIVE)
    (asserts! (< current-block (get policy-end-date policy)) ERR_POLICY_EXPIRED)
    (asserts! (> claim-amount-cents u0) ERR_INVALID_DATA)
    (asserts! (<= claim-amount-cents (get coverage-amount-cents policy)) ERR_INSUFFICIENT_COVERAGE)
    
    (map-set insurance-claims claim-id
      {
        policy-id: policy-id,
        animal-id: (get animal-id policy),
        claimant: tx-sender,
        claim-type: claim-type,
        claim-amount-cents: claim-amount-cents,
        incident-date: incident-date,
        incident-description: incident-description,
        veterinary-report: veterinary-report,
        supporting-documents: none,
        claim-status: "PENDING",
        assessor-notes: none,
        approved-amount-cents: u0,
        submitted-at: current-block,
        processed-at: none,
        processed-by: none
      }
    )
    
    (var-set last-claim-id claim-id)
    (ok claim-id)
  )
)

;; Process claim (assessor function)
(define-public (process-claim
  (claim-id uint)
  (approved bool)
  (approved-amount-cents uint)
  (assessor-notes (string-ascii 256))
)
  (let
    (
      (claim (unwrap! (map-get? insurance-claims claim-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (new-status (if approved "APPROVED" "DENIED"))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-assessor tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get claim-status claim) "PENDING") ERR_CLAIM_ALREADY_PROCESSED)
    
    (map-set insurance-claims claim-id
      (merge claim {
        claim-status: new-status,
        approved-amount-cents: approved-amount-cents,
        assessor-notes: (some assessor-notes),
        processed-at: (some current-block),
        processed-by: (some tx-sender)
      })
    )
    (ok true)
  )
)

;; Record risk assessment
(define-public (record-risk-assessment
  (animal-id uint)
  (risk-score uint)
  (health-history-score uint)
  (breed-risk-factor uint)
  (age-risk-factor uint)
  (farm-location-risk uint)
)
  (let
    ((current-block stacks-block-height))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-assessor tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (and (<= risk-score u100) (> risk-score u0)) ERR_INVALID_DATA)
    (asserts! (and (<= health-history-score u100) (> health-history-score u0)) ERR_INVALID_DATA)
    
    (map-set animal-risk-profiles animal-id
      {
        risk-score: risk-score,
        health-history-score: health-history-score,
        breed-risk-factor: breed-risk-factor,
        age-risk-factor: age-risk-factor,
        farm-location-risk: farm-location-risk,
        previous-claims: u0,
        last-assessment-date: current-block,
        assessed-by: tx-sender
      }
    )
    (ok true)
  )
)
