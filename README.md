# 🏦 AAVE-Inspired Lending Protocol (Simplified)

A simplified, from-scratch implementation of a decentralized lending protocol inspired by Aave. This project demonstrates core DeFi primitives such as liquidity provisioning, borrowing, interest accrual via indices, and liquidation mechanics — all built with scalability and mathematical correctness in mind.

---

# 🚀 Overview

This protocol allows users to:

* Supply assets and earn yield
* Borrow against collateral
* Repay borrowed funds
* Get liquidated if undercollateralized

It uses **index-based accounting** to efficiently distribute interest without iterating over users.

---

# 🧠 Core Concepts

## 1. Liquidity Index (Supplier Side)

Suppliers deposit assets and receive **scaled balances**.

```text
actualBalance = scaledBalance * liquidityIndex
```

* `liquidityIndex` increases when borrowers pay interest
* Suppliers earn yield automatically via index growth
* No per-user updates required

---

## 2. Borrow Index (Borrower Side)

Borrowers take loans tracked via **scaled debt**.

```text
actualDebt = scaledDebt * borrowIndex
```

* `borrowIndex` increases over time based on interest rate
* Debt grows automatically without updating user state
* Gas-efficient and scalable

---

## 3. Utilization-Based Interest Rate

Borrow rate depends on pool utilization:

```text
utilization = totalBorrowed / totalLiquidity
```

Two-slope model:

* Below optimal utilization → gentle slope
* Above optimal utilization → aggressive slope

---

## 4. Health Factor (Risk Engine)

Determines if a user is safe or can be liquidated:

```text
healthFactor = (collateral * liquidationThreshold) / debt
```

* `HF > 1` → Safe
* `HF < 1` → Liquidatable

---

## 5. Liquidation Mechanism

If a borrower becomes unsafe:

* Liquidator repays part of debt
* Receives collateral at a bonus (e.g. 110%)

Ensures protocol solvency.

---

# ⚙️ Architecture

## State Variables

### Global

* `totalLiquidity`
* `totalBorrowed`
* `liquidityIndex`
* `borrowIndex`

### User

* `scaledBalances` → supplier shares
* `scaledDebt` → borrower debt shares

---

# 🔄 Workflow

## 🟢 Supply

```text
1. User deposits asset
2. Convert to scaled balance:
   scaled = amount / liquidityIndex
3. Mint internal tokens
4. Increase totalLiquidity
```

---

## 🔵 Borrow

```text
1. Check collateral
2. Compute max borrow using LTV
3. Convert to scaled debt:
   scaledDebt += amount / borrowIndex
4. Transfer asset to user
5. Increase totalBorrowed
```

---

## 🟡 Repay

```text
1. Compute actual debt:
   debt = scaledDebt * borrowIndex
2. Accept repayment
3. Reduce scaledDebt accordingly
4. Decrease totalBorrowed
```

---

## 🔴 Withdraw

```text
1. Compute actual balance:
   balance = scaledBalance * liquidityIndex
2. Ensure sufficient collateral remains
3. Burn scaled balance
4. Transfer asset
5. Reduce totalLiquidity
```

---

## ⚫ Liquidation

```text
1. Check health factor < 1
2. Liquidator repays part of debt
3. Calculate collateral with bonus
4. Reduce borrower's scaled balance
5. Transfer collateral to liquidator
```

---

# 📈 Interest Accrual Model

## Borrow Side

```text
borrowIndex increases over time:
borrowIndex += (rate * timeElapsed)
```

## Supply Side

```text
liquidityIndex increases when interest is generated:
liquidityIndex += (interest / totalLiquidity)
```

---

# ⚡ Why Index-Based Design?

### ❌ Naive Approach

* Update each user individually
* High gas cost
* Not scalable

### ✅ Index-Based Approach

* O(1) updates
* No loops
* Production-grade design

---

# 🧪 Key Properties

* Fully on-chain accounting
* No per-user interest updates
* Deterministic math
* Gas-efficient
* Scales to large user base

---

# 🔥 Future Improvements

* Separate ERC20 tokens for:

  * Supply tokens (aTokens)
  * Debt tokens (variableDebtTokens)
* Stable borrow rates
* Flash loans
* Multi-asset support
* Oracle integration for pricing

---

# 🧾 Summary

This project captures the **core mechanics of a modern lending protocol**:

* Index-based yield distribution
* Scaled accounting system
* Dynamic interest rates
* Collateralized borrowing
* Liquidation engine

It serves as a strong foundation for building production-grade DeFi systems.

---

# 👨‍💻 Author Notes

This implementation is intentionally minimal yet architecturally aligned with real-world protocols. The focus is on understanding *why* each component exists, not just *how* to code it.

---


