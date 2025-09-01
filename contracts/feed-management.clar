;; Feed Management Contract for Herdtag Livestock Registry

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_DATA (err u202))
(define-constant ERR_INSUFFICIENT_SUPPLY (err u203))
(define-constant ERR_FEED_TYPE_EXISTS (err u204))
(define-constant ERR_SCHEDULE_CONFLICT (err u205))
(define-constant ERR_INVALID_ANIMAL (err u206))
(define-constant ERR_EXPIRED_FEED (err u207))

(define-data-var last-feed-type-id uint u0)
(define-data-var last-feeding-record-id uint u0)
(define-data-var last-schedule-id uint u0)

;; Feed type definition with nutritional content
(define-map feed-types
  uint
  {
    name: (string-ascii 64),
    category: (string-ascii 32), ;; HAY, GRAIN, SILAGE, SUPPLEMENT
    protein-percent: uint, ;; Percentage * 100 (e.g., 1850 = 18.5%)
    fat-percent: uint,
    fiber-percent: uint,
    moisture-percent: uint,
    energy-mcal-per-kg: uint, ;; Energy in mcal/kg * 1000
    cost-per-kg-cents: uint, ;; Cost in cents per kg
    supplier: (string-ascii 128),
    shelf-life-days: uint,
    species-suitability: (string-ascii 64), ;; CATTLE, SHEEP, GOAT, ALL
    created-at: uint,
    created-by: principal,
    is-active: bool
  }
)

;; Feed inventory tracking
(define-map feed-inventory
  uint ;; feed-type-id
  {
    current-stock-kg: uint,
    minimum-threshold-kg: uint,
    last-restocked-at: uint,
    last-restocked-by: principal,
    total-consumed-kg: uint,
    average-monthly-consumption-kg: uint,
    supplier-batch-number: (string-ascii 32),
    expiry-date: uint
  }
)

;; Animal feeding schedules
(define-map feeding-schedules
  uint ;; schedule-id
  {
    animal-id: uint,
    feed-type-id: uint,
    daily-amount-kg: uint, ;; Amount * 100 (e.g., 1250 = 12.5kg)
    feeding-times-per-day: uint,
    start-date: uint,
    end-date: (optional uint),
    schedule-name: (string-ascii 64),
    veterinarian-approved: bool,
    created-by: principal,
    created-at: uint,
    is-active: bool
  }
)

;; Individual feeding records
(define-map feeding-records
  uint ;; record-id
  {
    animal-id: uint,
    feed-type-id: uint,
    amount-consumed-kg: uint, ;; Amount * 100
    feeding-time: uint,
    recorded-by: principal,
    recorded-at: uint,
    notes: (optional (string-ascii 256)),
    feed-quality-rating: uint, ;; 1-10 scale
    animal-appetite: (string-ascii 16), ;; EXCELLENT, GOOD, FAIR, POOR
    weather-conditions: (optional (string-ascii 32)),
    schedule-id: (optional uint)
  }
)

;; Nutritional requirements by species and age group
(define-map nutritional-requirements
  {species: (string-ascii 32), age-group: (string-ascii 32)}
  {
    daily-protein-grams: uint,
    daily-energy-mcal: uint, ;; * 1000
    daily-fiber-grams: uint,
    daily-fat-grams: uint,
    min-feed-kg-per-day: uint, ;; * 100
    max-feed-kg-per-day: uint, ;; * 100
    special-supplements: (string-ascii 128),
    defined-by: principal,
    updated-at: uint
  }
)

;; Feed conversion efficiency tracking
(define-map feed-conversion-data
  uint ;; animal-id
  {
    total-feed-consumed-kg: uint, ;; * 100
    weight-gained-kg: uint, ;; * 100
    conversion-ratio: uint, ;; * 100 (feed consumed / weight gained)
    measurement-period-days: uint,
    last-updated: uint,
    efficiency-rating: (string-ascii 16) ;; EXCELLENT, GOOD, AVERAGE, POOR
  }
)

;; Monthly feed reports per animal
(define-map monthly-feed-reports
  {animal-id: uint, year: uint, month: uint}
  {
    total-consumed-kg: uint, ;; * 100
    total-cost-cents: uint,
    average-daily-intake-kg: uint, ;; * 100
    feed-types-used: (list 10 uint),
    weight-change-kg: int, ;; Can be negative, * 100
    health-improvements: (string-ascii 128),
    generated-at: uint,
    generated-by: principal
  }
)

;; Authorized feed managers
(define-map authorized-feed-managers principal bool)

;; Read-only functions
(define-read-only (get-feed-type (feed-type-id uint))
  (map-get? feed-types feed-type-id)
)

(define-read-only (get-feed-inventory (feed-type-id uint))
  (map-get? feed-inventory feed-type-id)
)

(define-read-only (get-feeding-schedule (schedule-id uint))
  (map-get? feeding-schedules schedule-id)
)

(define-read-only (get-feeding-record (record-id uint))
  (map-get? feeding-records record-id)
)

(define-read-only (get-nutritional-requirements (species (string-ascii 32)) (age-group (string-ascii 32)))
  (map-get? nutritional-requirements {species: species, age-group: age-group})
)

(define-read-only (get-feed-conversion-data (animal-id uint))
  (map-get? feed-conversion-data animal-id)
)

(define-read-only (get-monthly-feed-report (animal-id uint) (year uint) (month uint))
  (map-get? monthly-feed-reports {animal-id: animal-id, year: year, month: month})
)

(define-read-only (is-authorized-feed-manager (manager principal))
  (default-to false (map-get? authorized-feed-managers manager))
)

(define-read-only (get-last-feed-type-id)
  (var-get last-feed-type-id)
)

(define-read-only (get-last-feeding-record-id)
  (var-get last-feeding-record-id)
)

(define-read-only (get-last-schedule-id)
  (var-get last-schedule-id)
)

;; Check if feed type is suitable for specific animal species
(define-read-only (is-feed-suitable-for-species (feed-type-id uint) (species (string-ascii 32)))
  (match (map-get? feed-types feed-type-id)
    feed-data (or 
      (is-eq (get species-suitability feed-data) "ALL")
      (is-eq (get species-suitability feed-data) species)
    )
    false
  )
)

;; Calculate daily nutritional intake for an animal
(define-read-only (calculate-daily-nutrition (animal-id uint) (date uint))
  (ok {consumed-protein: u0, consumed-energy: u0, consumed-fiber: u0})
)

;; Admin functions
(define-public (authorize-feed-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-feed-managers manager true))
  )
)

(define-public (revoke-feed-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-delete authorized-feed-managers manager))
  )
)

;; Feed type management
(define-public (register-feed-type
  (name (string-ascii 64))
  (category (string-ascii 32))
  (protein-percent uint)
  (fat-percent uint)
  (fiber-percent uint)
  (moisture-percent uint)
  (energy-mcal-per-kg uint)
  (cost-per-kg-cents uint)
  (supplier (string-ascii 128))
  (shelf-life-days uint)
  (species-suitability (string-ascii 64))
)
  (let
    (
      (feed-type-id (+ (var-get last-feed-type-id) u1))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-feed-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_DATA)
    (asserts! (> (len category) u0) ERR_INVALID_DATA)
    (asserts! (<= (+ (+ protein-percent fat-percent) fiber-percent) u10000) ERR_INVALID_DATA)
    (asserts! (> cost-per-kg-cents u0) ERR_INVALID_DATA)
    
    (map-set feed-types feed-type-id
      {
        name: name,
        category: category,
        protein-percent: protein-percent,
        fat-percent: fat-percent,
        fiber-percent: fiber-percent,
        moisture-percent: moisture-percent,
        energy-mcal-per-kg: energy-mcal-per-kg,
        cost-per-kg-cents: cost-per-kg-cents,
        supplier: supplier,
        shelf-life-days: shelf-life-days,
        species-suitability: species-suitability,
        created-at: current-block,
        created-by: tx-sender,
        is-active: true
      }
    )
    
    (var-set last-feed-type-id feed-type-id)
    (ok feed-type-id)
  )
)

;; Inventory management
(define-public (update-feed-inventory
  (feed-type-id uint)
  (stock-added-kg uint)
  (minimum-threshold-kg uint)
  (supplier-batch-number (string-ascii 32))
  (expiry-date uint)
)
  (let
    (
      (current-inventory (default-to {
        current-stock-kg: u0,
        minimum-threshold-kg: u0,
        last-restocked-at: u0,
        last-restocked-by: CONTRACT_OWNER,
        total-consumed-kg: u0,
        average-monthly-consumption-kg: u0,
        supplier-batch-number: "",
        expiry-date: u0
      } (map-get? feed-inventory feed-type-id)))
      (new-stock (+ (get current-stock-kg current-inventory) stock-added-kg))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-feed-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? feed-types feed-type-id)) ERR_NOT_FOUND)
    (asserts! (> expiry-date current-block) ERR_EXPIRED_FEED)
    
    (map-set feed-inventory feed-type-id
      (merge current-inventory {
        current-stock-kg: new-stock,
        minimum-threshold-kg: minimum-threshold-kg,
        last-restocked-at: current-block,
        last-restocked-by: tx-sender,
        supplier-batch-number: supplier-batch-number,
        expiry-date: expiry-date
      })
    )
    (ok true)
  )
)

;; Create feeding schedule
(define-public (create-feeding-schedule
  (animal-id uint)
  (feed-type-id uint)
  (daily-amount-kg uint)
  (feeding-times-per-day uint)
  (start-date uint)
  (end-date (optional uint))
  (schedule-name (string-ascii 64))
  (veterinarian-approved bool)
)
  (let
    (
      (schedule-id (+ (var-get last-schedule-id) u1))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-feed-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? feed-types feed-type-id)) ERR_NOT_FOUND)
    (asserts! (> daily-amount-kg u0) ERR_INVALID_DATA)
    (asserts! (and (> feeding-times-per-day u0) (<= feeding-times-per-day u10)) ERR_INVALID_DATA)
    (asserts! (> (len schedule-name) u0) ERR_INVALID_DATA)
    
    (map-set feeding-schedules schedule-id
      {
        animal-id: animal-id,
        feed-type-id: feed-type-id,
        daily-amount-kg: daily-amount-kg,
        feeding-times-per-day: feeding-times-per-day,
        start-date: start-date,
        end-date: end-date,
        schedule-name: schedule-name,
        veterinarian-approved: veterinarian-approved,
        created-by: tx-sender,
        created-at: current-block,
        is-active: true
      }
    )
    
    (var-set last-schedule-id schedule-id)
    (ok schedule-id)
  )
)

;; Record feeding activity
(define-public (record-feeding
  (animal-id uint)
  (feed-type-id uint)
  (amount-consumed-kg uint)
  (notes (optional (string-ascii 256)))
  (feed-quality-rating uint)
  (animal-appetite (string-ascii 16))
  (weather-conditions (optional (string-ascii 32)))
  (schedule-id (optional uint))
)
  (let
    (
      (record-id (+ (var-get last-feeding-record-id) u1))
      (current-block stacks-block-height)
      (current-inventory (unwrap! (map-get? feed-inventory feed-type-id) ERR_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-feed-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? feed-types feed-type-id)) ERR_NOT_FOUND)
    (asserts! (> amount-consumed-kg u0) ERR_INVALID_DATA)
    (asserts! (and (> feed-quality-rating u0) (<= feed-quality-rating u10)) ERR_INVALID_DATA)
    (asserts! (>= (get current-stock-kg current-inventory) amount-consumed-kg) ERR_INSUFFICIENT_SUPPLY)
    
    ;; Record the feeding
    (map-set feeding-records record-id
      {
        animal-id: animal-id,
        feed-type-id: feed-type-id,
        amount-consumed-kg: amount-consumed-kg,
        feeding-time: current-block,
        recorded-by: tx-sender,
        recorded-at: current-block,
        notes: notes,
        feed-quality-rating: feed-quality-rating,
        animal-appetite: animal-appetite,
        weather-conditions: weather-conditions,
        schedule-id: schedule-id
      }
    )
    
    ;; Update inventory
    (map-set feed-inventory feed-type-id
      (merge current-inventory {
        current-stock-kg: (- (get current-stock-kg current-inventory) amount-consumed-kg),
        total-consumed-kg: (+ (get total-consumed-kg current-inventory) amount-consumed-kg)
      })
    )
    
    (var-set last-feeding-record-id record-id)
    (ok record-id)
  )
)

;; Set nutritional requirements
(define-public (set-nutritional-requirements
  (species (string-ascii 32))
  (age-group (string-ascii 32))
  (daily-protein-grams uint)
  (daily-energy-mcal uint)
  (daily-fiber-grams uint)
  (daily-fat-grams uint)
  (min-feed-kg-per-day uint)
  (max-feed-kg-per-day uint)
  (special-supplements (string-ascii 128))
)
  (let
    (
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> (len species) u0) ERR_INVALID_DATA)
    (asserts! (> (len age-group) u0) ERR_INVALID_DATA)
    (asserts! (< min-feed-kg-per-day max-feed-kg-per-day) ERR_INVALID_DATA)
    
    (map-set nutritional-requirements 
      {species: species, age-group: age-group}
      {
        daily-protein-grams: daily-protein-grams,
        daily-energy-mcal: daily-energy-mcal,
        daily-fiber-grams: daily-fiber-grams,
        daily-fat-grams: daily-fat-grams,
        min-feed-kg-per-day: min-feed-kg-per-day,
        max-feed-kg-per-day: max-feed-kg-per-day,
        special-supplements: special-supplements,
        defined-by: tx-sender,
        updated-at: current-block
      }
    )
    (ok true)
  )
)

;; Update feed conversion data
(define-public (update-feed-conversion-data
  (animal-id uint)
  (total-feed-consumed-kg uint)
  (weight-gained-kg uint)
  (measurement-period-days uint)
)
  (let
    (
      (current-block stacks-block-height)
      (conversion-ratio (if (> weight-gained-kg u0) 
        (/ total-feed-consumed-kg weight-gained-kg) 
        u0))
      (efficiency-rating 
        (if (<= conversion-ratio u300) "EXCELLENT"
        (if (<= conversion-ratio u500) "GOOD"  
        (if (<= conversion-ratio u700) "AVERAGE"
        "POOR"))))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-feed-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (> total-feed-consumed-kg u0) ERR_INVALID_DATA)
    (asserts! (> measurement-period-days u0) ERR_INVALID_DATA)
    
    (map-set feed-conversion-data animal-id
      {
        total-feed-consumed-kg: total-feed-consumed-kg,
        weight-gained-kg: weight-gained-kg,
        conversion-ratio: conversion-ratio,
        measurement-period-days: measurement-period-days,
        last-updated: current-block,
        efficiency-rating: efficiency-rating
      }
    )
    (ok true)
  )
)

;; Deactivate feeding schedule
(define-public (deactivate-feeding-schedule (schedule-id uint))
  (let
    (
      (schedule-data (unwrap! (map-get? feeding-schedules schedule-id) ERR_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-feed-manager tx-sender)) ERR_NOT_AUTHORIZED)
    
    (map-set feeding-schedules schedule-id
      (merge schedule-data {is-active: false})
    )
    (ok true)
  )
)

;; Generate monthly feed report
(define-public (generate-monthly-report
  (animal-id uint)
  (year uint)
  (month uint)
  (total-consumed-kg uint)
  (total-cost-cents uint)
  (feed-types-used (list 10 uint))
  (weight-change-kg int)
  (health-improvements (string-ascii 128))
)
  (let
    (
      (current-block stacks-block-height)
      (days-in-month (if (or (is-eq month u1) (is-eq month u3) (is-eq month u5) 
                            (is-eq month u7) (is-eq month u8) (is-eq month u10) (is-eq month u12)) u31
                        (if (or (is-eq month u4) (is-eq month u6) (is-eq month u9) (is-eq month u11)) u30 u28)))
      (average-daily-intake (/ total-consumed-kg days-in-month))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-feed-manager tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= month u1) (<= month u12)) ERR_INVALID_DATA)
    
    (map-set monthly-feed-reports 
      {animal-id: animal-id, year: year, month: month}
      {
        total-consumed-kg: total-consumed-kg,
        total-cost-cents: total-cost-cents,
        average-daily-intake-kg: average-daily-intake,
        feed-types-used: feed-types-used,
        weight-change-kg: weight-change-kg,
        health-improvements: health-improvements,
        generated-at: current-block,
        generated-by: tx-sender
      }
    )
    (ok true)
  )
)
