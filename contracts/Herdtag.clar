(define-non-fungible-token herdtag uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_DATA (err u103))
(define-constant ERR_NOT_OWNER (err u104))

(define-data-var last-animal-id uint u0)
(define-data-var contract-uri (optional (string-ascii 256)) none)

(define-map animals
  uint
  {
    species: (string-ascii 32),
    breed: (string-ascii 64),
    birth-date: uint,
    sex: (string-ascii 8),
    color: (string-ascii 32),
    weight: uint,
    farm-id: (string-ascii 64),
    sire-id: (optional uint),
    dam-id: (optional uint),
    registered-at: uint,
    registered-by: principal
  }
)

(define-map animal-history
  {animal-id: uint, event-id: uint}
  {
    event-type: (string-ascii 32),
    description: (string-ascii 256),
    timestamp: uint,
    recorded-by: principal,
    location: (optional (string-ascii 128)),
    weight: (optional uint),
    health-status: (optional (string-ascii 64))
  }
)

(define-map animal-event-counter uint uint)

(define-map authorized-registrars principal bool)

(define-read-only (get-last-animal-id)
  (var-get last-animal-id)
)

(define-read-only (get-animal (animal-id uint))
  (map-get? animals animal-id)
)

(define-read-only (get-animal-history (animal-id uint) (event-id uint))
  (map-get? animal-history {animal-id: animal-id, event-id: event-id})
)

(define-read-only (get-animal-event-count (animal-id uint))
  (default-to u0 (map-get? animal-event-counter animal-id))
)

(define-read-only (get-owner (animal-id uint))
  (nft-get-owner? herdtag animal-id)
)

(define-read-only (get-contract-uri)
  (var-get contract-uri)
)

(define-read-only (is-authorized-registrar (registrar principal))
  (default-to false (map-get? authorized-registrars registrar))
)

(define-public (set-contract-uri (uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (var-set contract-uri (some uri)))
  )
)

(define-public (authorize-registrar (registrar principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-registrars registrar true))
  )
)

(define-public (revoke-registrar (registrar principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-delete authorized-registrars registrar))
  )
)

(define-public (register-animal
  (species (string-ascii 32))
  (breed (string-ascii 64))
  (birth-date uint)
  (sex (string-ascii 8))
  (color (string-ascii 32))
  (weight uint)
  (farm-id (string-ascii 64))
  (sire-id (optional uint))
  (dam-id (optional uint))
  (recipient principal)
)
  (let 
    (
      (animal-id (+ (var-get last-animal-id) u1))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-registrar tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len species) u0) ERR_INVALID_DATA)
    (asserts! (> (len breed) u0) ERR_INVALID_DATA)
    (asserts! (> (len sex) u0) ERR_INVALID_DATA)
    (asserts! (> weight u0) ERR_INVALID_DATA)
    
    (try! (nft-mint? herdtag animal-id recipient))
    
    (map-set animals animal-id
      {
        species: species,
        breed: breed,
        birth-date: birth-date,
        sex: sex,
        color: color,
        weight: weight,
        farm-id: farm-id,
        sire-id: sire-id,
        dam-id: dam-id,
        registered-at: current-block,
        registered-by: tx-sender
      }
    )
    
    (map-set animal-event-counter animal-id u1)
    (map-set animal-history 
      {animal-id: animal-id, event-id: u1}
      {
        event-type: "BIRTH",
        description: "Animal registered and born",
        timestamp: current-block,
        recorded-by: tx-sender,
        location: (some farm-id),
        weight: (some weight),
        health-status: (some "HEALTHY")
      }
    )
    
    (var-set last-animal-id animal-id)
    (ok animal-id)
  )
)

(define-public (add-animal-event
  (animal-id uint)
  (event-type (string-ascii 32))
  (description (string-ascii 256))
  (location (optional (string-ascii 128)))
  (weight (optional uint))
  (health-status (optional (string-ascii 64)))
)
  (let
    (
      (current-event-count (get-animal-event-count animal-id))
      (new-event-id (+ current-event-count u1))
      (current-block stacks-block-height)
    )
    (asserts! (is-some (map-get? animals animal-id)) ERR_NOT_FOUND)
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-authorized-registrar tx-sender)
      (is-eq (some tx-sender) (nft-get-owner? herdtag animal-id))
    ) ERR_NOT_AUTHORIZED)
    
    (map-set animal-history
      {animal-id: animal-id, event-id: new-event-id}
      {
        event-type: event-type,
        description: description,
        timestamp: current-block,
        recorded-by: tx-sender,
        location: location,
        weight: weight,
        health-status: health-status
      }
    )
    
    (map-set animal-event-counter animal-id new-event-id)
    (ok new-event-id)
  )
)

(define-public (transfer (animal-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (try! (nft-transfer? herdtag animal-id sender recipient))
    (try! (add-animal-event animal-id "TRANSFER" "Ownership transferred" none none none))
    (ok true)
  )
)

(define-public (update-animal-weight (animal-id uint) (new-weight uint))
  (let
    (
      (animal-data (unwrap! (map-get? animals animal-id) ERR_NOT_FOUND))
    )
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-authorized-registrar tx-sender)
      (is-eq (some tx-sender) (nft-get-owner? herdtag animal-id))
    ) ERR_NOT_AUTHORIZED)
    
    (map-set animals animal-id (merge animal-data {weight: new-weight}))
    (try! (add-animal-event animal-id "WEIGHT_UPDATE" "Weight updated" none (some new-weight) none))
    (ok true)
  )
)

(define-public (mark-animal-health-status (animal-id uint) (status (string-ascii 64)) (notes (string-ascii 256)))
  (begin
    (asserts! (is-some (map-get? animals animal-id)) ERR_NOT_FOUND)
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-authorized-registrar tx-sender)
      (is-eq (some tx-sender) (nft-get-owner? herdtag animal-id))
    ) ERR_NOT_AUTHORIZED)
    
    (try! (add-animal-event animal-id "HEALTH_CHECK" notes none none (some status)))
    (ok true)
  )
)

(define-public (record-breeding (sire-id uint) (dam-id uint) (offspring-id uint))
  (let
    (
      (sire-data (unwrap! (map-get? animals sire-id) ERR_NOT_FOUND))
      (dam-data (unwrap! (map-get? animals dam-id) ERR_NOT_FOUND))
      (offspring-data (unwrap! (map-get? animals offspring-id) ERR_NOT_FOUND))
    )
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-authorized-registrar tx-sender)
    ) ERR_NOT_AUTHORIZED)
    
    (try! (add-animal-event sire-id "BREEDING" "Sired offspring" none none none))
    (try! (add-animal-event dam-id "BREEDING" "Gave birth to offspring" none none none))
    (try! (add-animal-event offspring-id "BIRTH" "Born from registered parents" none none (some "HEALTHY")))
    (ok true)
  )
)

(define-read-only (get-animals-by-owner (owner principal))
  (ok owner)
)

(define-read-only (get-animal-lineage (animal-id uint))
  (let
    (
      (animal-data (unwrap! (map-get? animals animal-id) ERR_NOT_FOUND))
    )
    (ok {
      sire: (get sire-id animal-data),
      dam: (get dam-id animal-data)
    })
  )
)
