# BTCVaultPool

BTCVaultPool is a cross-chain AMM liquidity pool for Bitcoin vault services on Stacks, providing automated market making functionality and decentralized liquidity provision for Bitcoin-STX trading pairs.

## Overview

BTCVaultPool implements a decentralized automated market maker (AMM) that enables users to provide liquidity, swap between BTC and STX, and manage Bitcoin vault services. The protocol uses a constant product formula for price discovery and includes comprehensive vault management features.

## Features

- **Automated Market Making**: Constant product AMM for BTC/STX trading pairs
- **Liquidity Provision**: Users can provide liquidity and earn LP tokens representing their share
- **Token Swapping**: Efficient BTC-to-STX and STX-to-BTC swaps with configurable fees
- **Vault Management**: Create and manage Bitcoin vaults with custom fee structures
- **Slippage Protection**: Built-in slippage tolerance for all trading operations
- **Fee Management**: 0.3% trading fee with protocol fee collection
- **Pool Controls**: Administrative functions for pausing/unpausing the pool
- **Metrics Tracking**: Comprehensive tracking of vault performance and utilization

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity 2.0
- **Token Standard**: SIP-010 compatible LP tokens
- **Fee Rate**: 0.3% (30/10000)
- **Minimum Liquidity**: 1000 units
- **Clarity Version**: 2
- **Epoch**: 2.5

## Contract Architecture

### Core Components

1. **LP Token**: `btc-vault-lp` fungible token representing liquidity shares
2. **Vault System**: Principal-based vault management with individual configurations
3. **AMM Engine**: Constant product market maker with fee collection
4. **Reserves Management**: Separate tracking of BTC and STX reserves

### Data Structures

- **Vaults Map**: Tracks vault balances, fees, and status
- **Liquidity Providers Map**: Records LP positions and contribution history
- **Vault Metrics Map**: Monitors vault performance and utilization rates

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- Node.js v18+
- npm or yarn

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd BTCVaultPool
```

2. Install dependencies:
```bash
cd BTCVaultPool_contract
npm install
```

3. Run tests:
```bash
npm test
```

4. Generate coverage report:
```bash
npm run test:report
```

## Usage Examples

### Deploying the Contract

```bash
clarinet deploy --testnet
```

### Creating a Vault

```clarity
;; Create a vault with 1% fee (100 basis points)
(contract-call? .BTCVaultPool create-vault u100)
```

### Adding Liquidity

```clarity
;; Add 1000000 micro-BTC and 50000000 micro-STX, expect at least 7000000 LP tokens
(contract-call? .BTCVaultPool add-liquidity u1000000 u50000000 u7000000)
```

### Removing Liquidity

```clarity
;; Remove 1000000 LP tokens, expect at least 100000 micro-BTC and 5000000 micro-STX
(contract-call? .BTCVaultPool remove-liquidity u1000000 u100000 u5000000)
```

### Token Swapping

```clarity
;; Swap 500000 micro-BTC for STX, expect at least 24000000 micro-STX
(contract-call? .BTCVaultPool swap-btc-for-stx u500000 u24000000)

;; Swap 25000000 micro-STX for BTC, expect at least 480000 micro-BTC
(contract-call? .BTCVaultPool swap-stx-for-btc u25000000 u480000)
```

## Contract Functions

### Public Functions

#### Vault Management

- `create-vault(vault-fee: uint)` - Create a new vault with specified fee rate
- `update-vault-status(active: bool)` - Enable/disable vault operations

#### Liquidity Operations

- `add-liquidity(btc-amount: uint, stx-amount: uint, min-lp-tokens: uint)` - Provide liquidity to the pool
- `remove-liquidity(lp-tokens: uint, min-btc-out: uint, min-stx-out: uint)` - Remove liquidity from the pool

#### Trading Operations

- `swap-btc-for-stx(btc-amount: uint, min-stx-out: uint)` - Swap BTC for STX
- `swap-stx-for-btc(stx-amount: uint, min-btc-out: uint)` - Swap STX for BTC

#### Administrative Functions

- `pause-pool()` - Pause all pool operations (owner only)
- `unpause-pool()` - Resume pool operations (owner only)
- `set-fee-collector(new-collector: principal)` - Update protocol fee collector (owner only)

### Read-Only Functions

#### Pool Information

- `get-pool-reserves()` - Returns current BTC/STX reserves and total LP supply
- `get-price-ratio()` - Returns current STX/BTC price ratio
- `is-pool-paused()` - Returns pool pause status

#### User Information

- `get-vault-info(vault-owner: principal)` - Returns vault configuration and balances
- `get-lp-info(provider: principal)` - Returns liquidity provider position
- `get-vault-metrics(vault-owner: principal)` - Returns vault performance metrics

#### Utility Functions

- `get-swap-output(input-amount: uint, input-reserve: uint, output-reserve: uint)` - Calculate swap output amount

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `err-owner-only` | Operation restricted to contract owner |
| 101 | `err-insufficient-balance` | Insufficient token balance |
| 102 | `err-insufficient-liquidity` | Insufficient pool liquidity |
| 103 | `err-invalid-amount` | Invalid amount specified |
| 104 | `err-slippage-exceeded` | Slippage tolerance exceeded |
| 105 | `err-vault-not-found` | Vault does not exist |
| 106 | `err-vault-already-exists` | Vault already exists for address |
| 107 | `err-pool-paused` | Pool operations are paused |

## Deployment Guide

### Testnet Deployment

1. Configure your Clarinet.toml with testnet settings
2. Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Update Clarinet.toml for mainnet
2. Ensure thorough testing and audit completion
3. Deploy with proper security measures:
```bash
clarinet deploy --mainnet
```

### Post-Deployment Steps

1. Verify contract deployment on Stacks Explorer
2. Initialize initial liquidity pools
3. Configure monitoring and alerting systems
4. Set up protocol fee collection

## Security Considerations

### Smart Contract Security

- **Reentrancy Protection**: All state changes occur before external calls
- **Integer Overflow Protection**: Clarity's built-in safe arithmetic prevents overflows
- **Access Control**: Administrative functions restricted to contract owner
- **Input Validation**: Comprehensive validation of all user inputs

### Operational Security

- **Pause Mechanism**: Emergency stop functionality for critical situations
- **Slippage Protection**: User-defined slippage tolerance for all trades
- **Minimum Liquidity**: Prevents liquidity drain attacks
- **Fee Validation**: Configurable but bounded fee rates

### Audit Recommendations

- Conduct comprehensive smart contract audit before mainnet deployment
- Implement formal verification for critical mathematical operations
- Establish incident response procedures
- Monitor pool metrics and unusual trading patterns

### Best Practices

- Use read-only functions for price queries to prevent manipulation
- Implement proper frontend slippage calculations
- Monitor gas costs and optimize transaction batching
- Establish governance procedures for parameter updates

## Development

### Running Tests

```bash
npm test
```

### Running Tests with Coverage

```bash
npm run test:report
```

### Watch Mode for Development

```bash
npm run test:watch
```

### Code Structure

```
BTCVaultPool_contract/
├── contracts/
│   └── BTCVaultPool.clar     # Main contract implementation
├── tests/                    # Test files
├── Clarinet.toml            # Clarinet configuration
└── package.json             # Node.js dependencies
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with comprehensive tests
4. Ensure all tests pass
5. Submit a pull request with detailed description

## License

This project is licensed under the ISC License.

## Disclaimer

This software is provided as-is without any warranties. Users should conduct their own security audits and risk assessments before using this contract in production environments. The authors are not responsible for any financial losses or security breaches.