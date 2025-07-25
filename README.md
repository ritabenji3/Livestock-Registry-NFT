# 🐄 Herdtag - Livestock Registry NFT

A comprehensive blockchain-based livestock registry system built on Stacks using Clarity smart contracts. Each animal gets a unique NFT with complete history tracking and lineage records.

## 🌟 Features

- **🏷️ Unique Animal NFTs**: Each animal gets a unique token ID with complete ownership tracking
- **📋 Comprehensive Records**: Store species, breed, birth date, weight, color, and farm information  
- **🧬 Lineage Tracking**: Track sire and dam relationships for breeding programs
- **📝 Event History**: Record all major events (birth, health checks, weight updates, transfers)
- **👥 Multi-User Access**: Support for authorized registrars and animal owners
- **🏥 Health Monitoring**: Track health status and veterinary records
- **🔄 Ownership Transfers**: Secure NFT transfers with automatic event logging

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testnet/mainnet deployment

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd herdtag

# Install dependencies
npm install

# Run tests
clarinet test

# Deploy to testnet
clarinet integrate
```

## 📖 Usage

### 🆕 Register a New Animal

```clarity
(contract-call? .herdtag register-animal 
  "CATTLE"           ;; species
  "Holstein"         ;; breed  
  u1640995200        ;; birth-date (Unix timestamp)
  "FEMALE"           ;; sex
  "BLACK_WHITE"      ;; color
  u450               ;; weight (kg)
  "FARM001"          ;; farm-id
  none               ;; sire-id (optional)
  none               ;; dam-id (optional)  
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM ;; recipient
)
```

### 📊 Query Animal Information

```clarity
;; Get animal details
(contract-call? .herdtag get-animal u1)

;; Get ownership
(contract-call? .herdtag get-owner u1)

;; Get event history  
(contract-call? .herdtag get-animal-history u1 u1)

;; Get lineage
(contract-call? .herdtag get-animal-lineage u1)
```

### 📝 Add Events

```clarity
;; Add health check
(contract-call? .herdtag add-animal-event
  u1                 ;; animal-id
  "HEALTH_CHECK"     ;; event-type
  "Annual vaccination completed" ;; description
  (some "VET_CLINIC_A")         ;; location
  none                          ;; weight
  (some "HEALTHY")              ;; health-status
)

;; Update weight
(contract-call? .herdtag update-animal-weight u1 u475)
```

### 🔄 Transfer Ownership

```clarity
(contract-call? .herdtag transfer 
  u1                                      ;; animal-id
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM ;; sender
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG ;; recipient
)
```

### 👨‍💼 Admin Functions

```clarity
;; Authorize registrar
(contract-call? .herdtag authorize-registrar 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Set contract metadata URI
(contract-call? .herdtag set-contract-uri "https://api.herdtag.com/metadata")
```

## 🏗️ Contract Architecture

### Data Structures

- **🐄 Animals Map**: Core animal information (species, breed, birth data, etc.)
- **📚 History Map**: Complete event history for each animal
- **🔢 Event Counter**: Tracks number of events per animal
- **👤 Authorized Registrars**: Principals allowed to register animals

### Key Functions

| Function | Purpose | Access Level |
|----------|---------|--------------|
| `register-animal` | 🆕 Create new animal NFT | Owner/Registrar |
| `add-animal-event` | 📝 Add history event | Owner/Registrar/NFT Owner |
| `transfer` | 🔄 Transfer ownership | NFT Owner |
| `update-animal-weight` | ⚖️ Update weight | Owner/Registrar/NFT Owner |
| `mark-animal-health-status` | 🏥 Record health info | Owner/Registrar/NFT Owner |
| `record-breeding` | 🧬 Link breeding records | Owner/Registrar |

## 🔒 Security Features

- **Access Control**: Multi-level permission system
- **Data Validation**: Input validation for all parameters  
- **NFT Compliance**: Full SIP-009 compatibility
- **Event Integrity**: Immutable history tracking
- **Owner Verification**: Secure ownership checks

## 🧪 Testing

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/herdtag_test.ts

# Check contract
clarinet check
```

## 🌐 API Reference

### Read-Only Functions

- `get-animal(animal-id)` - Get animal details
- `get-owner(animal-id)` - Get NFT owner
- `get-animal-history(animal-id, event-id)` - Get specific event
- `get-animal-event-count(animal-id)` - Get total events
- `get-animal-lineage(animal-id)` - Get parent information
- `is-authorized-registrar(principal)` - Check registrar status

### Public Functions

- `register-animal(...)` - Register new animal
- `add-animal-event(...)` - Add history event  
- `transfer(...)` - Transfer ownership
- `update-animal-weight(...)` - Update weight
- `mark-animal-health-status(...)` - Record health status
- `record-breeding(...)` - Link breeding records

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙋‍♂️ Support

For questions and support:
- 📧 Email: support@herdtag.com
- 💬 Discord: [Herdtag Community](https://discord.gg/herdtag)
