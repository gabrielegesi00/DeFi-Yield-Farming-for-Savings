# 🌾 DeFi Yield Farming for Savings

> **Empowering financial inclusion through Bitcoin-backed yield farming on Stacks** 💰

## 📋 Overview

This smart contract enables users to stake STX tokens in yield farming pools to earn rewards over time, promoting financial inclusion by providing accessible savings opportunities in the DeFi ecosystem.

## ✨ Key Features

- 🏦 **Multiple Staking Pools**: Create and manage different yield farming pools
- 💎 **Flexible Staking**: Stake any amount above the minimum threshold
- 🎯 **Real-time Rewards**: Calculate and claim rewards based on staking duration
- 🛡️ **Safety Controls**: Emergency shutdown and pool management features
- 🔄 **Easy Unstaking**: Withdraw principal plus earned rewards anytime
- 📊 **Transparent Stats**: View pool information and user statistics

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- STX wallet with sufficient balance

### 📦 Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/DeFi-Yield-Farming-for-Savings.git
cd DeFi-Yield-Farming-for-Savings
```

2. Check the contract:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 🎮 Usage Instructions

### For Pool Creators (Contract Owner)

#### 1️⃣ Create a New Pool
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings create-pool 
  "High Yield Pool" 
  u500000    ;; 0.5% reward rate
  u1000000)  ;; 1 STX minimum stake
```

#### 2️⃣ Toggle Pool Status
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings toggle-pool u1)
```

#### 3️⃣ Emergency Controls
```clarity
;; Emergency shutdown
(contract-call? .DeFi-Yield-Farming-for-Savings emergency-stop)

;; Resume operations  
(contract-call? .DeFi-Yield-Farming-for-Savings resume-operations)
```

### For Stakers (Users)

#### 1️⃣ Stake STX Tokens
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings stake u1 u5000000) ;; Pool 1, 5 STX
```

#### 2️⃣ Claim Rewards
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings claim-rewards u1)
```

#### 3️⃣ Check Pending Rewards
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings get-pending-rewards tx-sender u1)
```

#### 4️⃣ Unstake (Principal + Rewards)
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings unstake u1)
```

### 📊 View Information

#### Pool Information
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings get-pool-info u1)
```

#### User Stake Details
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings get-user-stake-info tx-sender u1)
```

#### Contract Statistics
```clarity
(contract-call? .DeFi-Yield-Farming-for-Savings get-contract-stats)
```

## 🏗️ Contract Architecture

### 📝 Data Structures

- **Pools**: Store pool configuration and statistics
- **User Stakes**: Track individual staking positions
- **User Pool Count**: Monitor user engagement across pools

### 🔧 Core Functions

| Function | Type | Description |
|----------|------|-------------|
| `create-pool` | Public | Create new staking pool |
| `stake` | Public | Stake STX in a pool |
| `claim-rewards` | Public | Claim accumulated rewards |
| `unstake` | Public | Withdraw stake + rewards |
| `get-pending-rewards` | Read-only | Check unclaimed rewards |
| `get-pool-info` | Read-only | View pool details |

### 💸 Reward Calculation

Rewards are calculated using the formula:
```
Rewards = (Staked Amount × Pool Rate × Blocks Elapsed) ÷ 100,000,000
```

## 🛡️ Security Features

- ✅ Owner-only administrative functions
- ✅ Emergency shutdown capability  
- ✅ Input validation and error handling
- ✅ Reentrancy protection through proper state management
- ✅ Minimum stake requirements

## ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| `u1` | ERR-UNAUTHORIZED | Caller not authorized |
| `u2` | ERR-INSUFFICIENT-BALANCE | Insufficient STX balance |
| `u3` | ERR-POOL-NOT-FOUND | Pool doesn't exist |
| `u4` | ERR-ALREADY-STAKED | User already has stake in pool |
| `u5` | ERR-NOT-STAKED | No active stake found |
| `u6` | ERR-INVALID-AMOUNT | Invalid amount provided |
| `u7` | ERR-COOLDOWN-ACTIVE | Cooldown period active |
| `u8` | ERR-POOL-INACTIVE | Pool not active |

## 🎯 Financial Inclusion Benefits

- 💰 **Low Barriers**: Flexible minimum stakes for all income levels
- 🌍 **Global Access**: Permissionless participation via blockchain
- 📈 **Passive Income**: Earn yields on Bitcoin-backed assets  
- 🔓 **No Lock-in**: Unstake anytime with accumulated rewards
- 📱 **Simple Interface**: Easy-to-use staking functions

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⭐ Support

If you find this project helpful, please give it a star! ⭐

---

**Built with ❤️ for the Stacks ecosystem**
