;; Breeding Management and Genetic Tracking System
;; Advanced livestock breeding program management with genetic trait tracking

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_DATA (err u302))
(define-constant ERR_BREEDING_CONFLICT (err u303))
(define-constant ERR_ANIMAL_TOO_YOUNG (err u304))
(define-constant ERR_GENETIC_INCOMPATIBLE (err u305))
(define-constant ERR_ALREADY_BREEDING (err u306))

(define-data-var last-breeding-record-id uint u0)
(define-data-var last-genetic-test-id uint u0)
(define-data-var last-breeding-program-id uint u0)

;; Genetic traits tracking
(define-map genetic-profiles
  uint ;; animal-id
  {
    coat-color-genes: (string-ascii 32), ;; Dominant/recessive alleles
    horn-genes: (string-ascii 16), ;; POLLED, HORNED, CARRIER
    muscle-development: uint, ;; Score 1-10
    milk-production-genes: (string-ascii 32),
    disease-resistance-markers: (list 5 (string-ascii 32)),
    growth-rate-genes: (string-ascii 32),
    fertility-genes: (string-ascii 32),
    temperament-genes: (string-ascii 16), ;; CALM, MODERATE, ACTIVE
    last-tested: uint,
    genetic-diversity-score: uint, ;; 1-100
    tested-by: principal
  }
)

;; Breeding records with detailed tracking
(define-map breeding-records
  uint ;; breeding-record-id
  {
    sire-id: uint,
    dam-id: uint,
    breeding-date: uint,
    expected-calving-date: uint,
    actual-calving-date: (optional uint),
    breeding-method: (string-ascii 32), ;; NATURAL, AI, ET
    breeding-success: (optional bool),
    offspring-count: uint,
    offspring-ids: (list 5 uint),
    breeding-notes: (optional (string-ascii 256)),
    veterinarian: (optional principal),
    breeding-program-id: (optional uint),
    recorded-by: principal,
    recorded-at: uint
  }
)

;; Breeding programs for systematic genetic improvement
(define-map breeding-programs
  uint ;; program-id
  {
    program-name: (string-ascii 64),
    breeding-objectives: (string-ascii 256),
    target-traits: (list 10 (string-ascii 32)),
    selection-criteria: (string-ascii 256),
    program-manager: principal,
    start-date: uint,
    end-date: (optional uint),
    participating-animals: (list 50 uint),
    success-metrics: (string-ascii 256),
    genetic-goals: (string-ascii 256),
    is-active: bool,
    created-by: principal,
    created-at: uint
  }
)

;; Breeding performance analytics
(define-map breeding-performance
  uint ;; animal-id
  {
    breeding-attempts: uint,
    successful-breedings: uint,
    offspring-produced: uint,
    average-offspring-per-breeding: uint, ;; * 100
    last-breeding-date: (optional uint),
    fertility-score: uint, ;; 1-100
    genetic-contribution-score: uint, ;; 1-100
    breeding-efficiency: uint, ;; 1-100
    preferred-breeding-season: (string-ascii 16), ;; SPRING, SUMMER, FALL, WINTER
    breeding-restrictions: (optional (string-ascii 128))
  }
)

;; Genetic compatibility analysis
(define-map genetic-compatibility
  {sire-id: uint, dam-id: uint}
  {
    compatibility-score: uint, ;; 1-100
    risk-factors: (list 5 (string-ascii 64)),
    predicted-traits: (list 10 (string-ascii 64)),
    genetic-diversity-gain: int, ;; Can be negative
    breeding-recommendation: (string-ascii 16), ;; EXCELLENT, GOOD, FAIR, AVOID
    analysis-date: uint,
    analyzed-by: principal
  }
)

;; Breeding calendar and scheduling
(define-map breeding-schedule
  {animal-id: uint, planned-date: uint}
  {
    partner-id: uint,
    breeding-type: (string-ascii 16), ;; PLANNED, EMERGENCY, RESEARCH
    preparation-notes: (string-ascii 256),
    veterinary-required: bool,
    breeding-program-id: (optional uint),
    scheduled-by: principal,
    scheduled-at: uint,
    status: (string-ascii 16) ;; SCHEDULED, COMPLETED, CANCELLED, POSTPONED
  }
)

;; Offspring tracking with genetic predictions vs reality
(define-map offspring-analysis
  uint ;; offspring-id
  {
    predicted-traits: (list 10 (string-ascii 64)),
    actual-traits: (list 10 (string-ascii 64)),
    trait-accuracy-score: uint, ;; 1-100
    growth-performance: uint, ;; 1-100 vs expectations
    health-score: uint, ;; 1-100
    genetic-markers-confirmed: (list 5 bool),
    breeding-value-estimate: uint, ;; 1-1000
    future-breeding-potential: (string-ascii 16), ;; HIGH, MEDIUM, LOW, EXCLUDE
    analysis-completed-at: uint
  }
)

;; Authorized breeding managers and geneticists
(define-map authorized-breeding-managers principal bool)
(define-map authorized-geneticists principal bool)

;; Read-only functions
(define-read-only (get-genetic-profile (animal-id uint))
  (map-get? genetic-profiles animal-id)
)

(define-read-only (get-breeding-record (record-id uint))
  (map-get? breeding-records record-id)
)

(define-read-only (get-breeding-program (program-id uint))
  (map-get? breeding-programs program-id)
)

(define-read-only (get-breeding-performance (animal-id uint))
  (map-get? breeding-performance animal-id)
)

(define-read-only (get-genetic-compatibility (sire-id uint) (dam-id uint))
  (map-get? genetic-compatibility {sire-id: sire-id, dam-id: dam-id})
)

(define-read-only (get-breeding-schedule (animal-id uint) (planned-date uint))
  (map-get? breeding-schedule {animal-id: animal-id, planned-date: planned-date})
)

(define-read-only (get-offspring-analysis (offspring-id uint))
  (map-get? offspring-analysis offspring-id)
)

(define-read-only (is-authorized-breeding-manager (manager principal))
  (default-to false (map-get? authorized-breeding-managers manager))
)

(define-read-only (is-authorized-geneticist (geneticist principal))
  (default-to false (map-get? authorized-geneticists geneticist))
)

;; Authorization functions
(define-public (authorize-breeding-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-breeding-managers manager true))
  )
)

(define-public (authorize-geneticist (geneticist principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-geneticists geneticist true))
  )
)

;; Record genetic profile
(define-public (record-genetic-profile
  (animal-id uint)
  (coat-color-genes (string-ascii 32))
  (horn-genes (string-ascii 16))
  (muscle-development uint)
  (milk-production-genes (string-ascii 32))
  (disease-resistance-markers (list 5 (string-ascii 32)))
  (growth-rate-genes (string-ascii 32))
  (fertility-genes (string-ascii 32))
  (temperament-genes (string-ascii 16))
  (genetic-diversity-score uint)
)
  (let
    ((current-block stacks-block-height))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-geneticist tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (and (> muscle-development u0) (<= muscle-development u10)) ERR_INVALID_DATA)
    (asserts! (and (> genetic-diversity-score u0) (<= genetic-diversity-score u100)) ERR_INVALID_DATA)
    
    (map-set genetic-profiles animal-id
      {
        coat-color-genes: coat-color-genes,
        horn-genes: horn-genes,
        muscle-development: muscle-development,
        milk-production-genes: milk-production-genes,
        disease-resistance-markers: disease-resistance-markers,
        growth-rate-genes: growth-rate-genes,
        fertility-genes: fertility-genes,
        temperament-genes: temperament-genes,
        last-tested: current-block,
        genetic-diversity-score: genetic-diversity-score,
        tested-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Create breeding program
(define-public (create-breeding-program
  (program-name (string-ascii 64))
  (breeding-objectives (string-ascii 256))
  (target-traits (list 10 (string-ascii 32)))
  (selection-criteria (string-ascii 256))
  (genetic-goals (string-ascii 256))
)
  (let
    (
      (program-id (+ (var-get last-breeding-program-id) u1))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-breeding-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len program-name) u0) ERR_INVALID_DATA)
    (asserts! (> (len breeding-objectives) u0) ERR_INVALID_DATA)
    
    (map-set breeding-programs program-id
      {
        program-name: program-name,
        breeding-objectives: breeding-objectives,
        target-traits: target-traits,
        selection-criteria: selection-criteria,
        program-manager: tx-sender,
        start-date: current-block,
        end-date: none,
        participating-animals: (list),
        success-metrics: "",
        genetic-goals: genetic-goals,
        is-active: true,
        created-by: tx-sender,
        created-at: current-block
      }
    )
    
    (var-set last-breeding-program-id program-id)
    (ok program-id)
  )
)

;; Record breeding event
(define-public (record-breeding
  (sire-id uint)
  (dam-id uint)
  (breeding-date uint)
  (expected-calving-date uint)
  (breeding-method (string-ascii 32))
  (breeding-notes (optional (string-ascii 256)))
  (veterinarian (optional principal))
  (breeding-program-id (optional uint))
)
  (let
    (
      (record-id (+ (var-get last-breeding-record-id) u1))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-breeding-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq sire-id dam-id)) ERR_INVALID_DATA)
    (asserts! (> expected-calving-date breeding-date) ERR_INVALID_DATA)
    
    (map-set breeding-records record-id
      {
        sire-id: sire-id,
        dam-id: dam-id,
        breeding-date: breeding-date,
        expected-calving-date: expected-calving-date,
        actual-calving-date: none,
        breeding-method: breeding-method,
        breeding-success: none,
        offspring-count: u0,
        offspring-ids: (list),
        breeding-notes: breeding-notes,
        veterinarian: veterinarian,
        breeding-program-id: breeding-program-id,
        recorded-by: tx-sender,
        recorded-at: current-block
      }
    )
    
    ;; Update breeding performance for both parents
    (unwrap! (update-breeding-performance sire-id) ERR_INVALID_DATA)
    (unwrap! (update-breeding-performance dam-id) ERR_INVALID_DATA)
    
    (var-set last-breeding-record-id record-id)
    (ok record-id)
  )
)

;; Analyze genetic compatibility
(define-public (analyze-genetic-compatibility
  (sire-id uint)
  (dam-id uint)
  (compatibility-score uint)
  (risk-factors (list 5 (string-ascii 64)))
  (predicted-traits (list 10 (string-ascii 64)))
  (genetic-diversity-gain int)
  (breeding-recommendation (string-ascii 16))
)
  (let
    ((current-block stacks-block-height))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-geneticist tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (and (> compatibility-score u0) (<= compatibility-score u100)) ERR_INVALID_DATA)
    (asserts! (not (is-eq sire-id dam-id)) ERR_INVALID_DATA)
    
    (map-set genetic-compatibility 
      {sire-id: sire-id, dam-id: dam-id}
      {
        compatibility-score: compatibility-score,
        risk-factors: risk-factors,
        predicted-traits: predicted-traits,
        genetic-diversity-gain: genetic-diversity-gain,
        breeding-recommendation: breeding-recommendation,
        analysis-date: current-block,
        analyzed-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Schedule breeding
(define-public (schedule-breeding
  (animal-id uint)
  (partner-id uint)
  (planned-date uint)
  (breeding-type (string-ascii 16))
  (preparation-notes (string-ascii 256))
  (veterinary-required bool)
  (breeding-program-id (optional uint))
)
  (let
    ((current-block stacks-block-height))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-breeding-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (> planned-date current-block) ERR_INVALID_DATA)
    (asserts! (not (is-eq animal-id partner-id)) ERR_INVALID_DATA)
    
    (map-set breeding-schedule
      {animal-id: animal-id, planned-date: planned-date}
      {
        partner-id: partner-id,
        breeding-type: breeding-type,
        preparation-notes: preparation-notes,
        veterinary-required: veterinary-required,
        breeding-program-id: breeding-program-id,
        scheduled-by: tx-sender,
        scheduled-at: current-block,
        status: "SCHEDULED"
      }
    )
    (ok true)
  )
)

;; Update breeding performance (internal function)
(define-private (update-breeding-performance (animal-id uint))
  (let
    (
      (current-performance (default-to
        {
          breeding-attempts: u0,
          successful-breedings: u0,
          offspring-produced: u0,
          average-offspring-per-breeding: u0,
          last-breeding-date: none,
          fertility-score: u50,
          genetic-contribution-score: u50,
          breeding-efficiency: u50,
          preferred-breeding-season: "SPRING",
          breeding-restrictions: none
        }
        (map-get? breeding-performance animal-id)
      ))
      (new-attempts (+ (get breeding-attempts current-performance) u1))
      (current-block stacks-block-height)
    )
    
    (map-set breeding-performance animal-id
      (merge current-performance {
        breeding-attempts: new-attempts,
        last-breeding-date: (some current-block)
      })
    )
    (ok true)
  )
)

;; Record offspring results
(define-public (record-offspring-analysis
  (offspring-id uint)
  (predicted-traits (list 10 (string-ascii 64)))
  (actual-traits (list 10 (string-ascii 64)))
  (trait-accuracy-score uint)
  (growth-performance uint)
  (health-score uint)
  (genetic-markers-confirmed (list 5 bool))
  (breeding-value-estimate uint)
  (future-breeding-potential (string-ascii 16))
)
  (let
    ((current-block stacks-block-height))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-geneticist tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (and (> trait-accuracy-score u0) (<= trait-accuracy-score u100)) ERR_INVALID_DATA)
    (asserts! (and (> growth-performance u0) (<= growth-performance u100)) ERR_INVALID_DATA)
    (asserts! (and (> health-score u0) (<= health-score u100)) ERR_INVALID_DATA)
    (asserts! (and (> breeding-value-estimate u0) (<= breeding-value-estimate u1000)) ERR_INVALID_DATA)
    
    (map-set offspring-analysis offspring-id
      {
        predicted-traits: predicted-traits,
        actual-traits: actual-traits,
        trait-accuracy-score: trait-accuracy-score,
        growth-performance: growth-performance,
        health-score: health-score,
        genetic-markers-confirmed: genetic-markers-confirmed,
        breeding-value-estimate: breeding-value-estimate,
        future-breeding-potential: future-breeding-potential,
        analysis-completed-at: current-block
      }
    )
    (ok true)
  )
)

;; Calculate breeding value for an animal
(define-read-only (calculate-breeding-value (animal-id uint))
  (let
    (
      (genetic-profile (map-get? genetic-profiles animal-id))
      (performance-data (map-get? breeding-performance animal-id))
    )
    (match genetic-profile
      profile (match performance-data
        perf-data (ok {
          genetic-score: (get genetic-diversity-score profile),
          performance-score: (get fertility-score perf-data),
          overall-breeding-value: (/ (+ (get genetic-diversity-score profile) (get fertility-score perf-data)) u2)
        })
        (ok {genetic-score: (get genetic-diversity-score profile), performance-score: u0, overall-breeding-value: (get genetic-diversity-score profile)})
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Generate breeding recommendations
(define-read-only (get-breeding-recommendations (animal-id uint))
  (let
    (
      (genetic-profile (map-get? genetic-profiles animal-id))
      (performance-data (map-get? breeding-performance animal-id))
    )
    (match genetic-profile
      profile (ok {
        recommended-traits-to-improve: (list "MILK_PRODUCTION" "DISEASE_RESISTANCE"),
        optimal-breeding-season: "SPRING",
        genetic-diversity-needs: (if (< (get genetic-diversity-score profile) u50) "HIGH" "MODERATE"),
        breeding-readiness: (if (is-some (get last-breeding-date performance-data)) "READY" "EVALUATE")
      })
      (err ERR_NOT_FOUND)
    )
  )
)
