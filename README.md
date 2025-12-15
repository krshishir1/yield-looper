# Yield Looper

## Overview

Yield Looper is a decentralized automation strategy for lending protocols (Aave V3). It automates the "looping" of collateral to maximize yield exposure.

The strategy involves:
1.  **Supply Collateral**: Deposit WETH into Aave.
2.  **Borrow Debt**: Borrow WBTC against the collateral.
3.  **Swap & Reinvest**: Swap borrowed WBTC for more WETH and supply it back to Aave.
4.  **Repeat**: Continue loop until target leverage or health factor is reached.

This project utilizes **Reactive Network** to autonomously monitor the position's health factor and trigger rebalancing (Looping) or emergency unwinding (Repay & Withdraw) based on on-chain events.

## Contracts

### `LeverageLoop.sol`
The main vault contract that holds the user's position.
-   Manages interactions with Aave V3 (Supply, Borrow, Repay, Withdraw).
-   Executes the looping strategy (`supplyAndBorrow` and `executeLoop`).
-   Emits `LeverageLoop` events to signal state to the Reactive Network.

### `LeverageLoopReactive.sol`
A Reactive Smart Contract (RSC) that listens to events affecting the `LeverageLoop`.
-   **Loop Automation**: Listens for `LeverageLoop` events. If conditions (Health Factor > Target) are met, it triggers another loop cycle (`reinvest`).
-   **Emergency Unwind**: Listens for liquidation risks (e.g., `LiquidationCall`). Triggers `repayAndWithdrawFunds` to protect the user's capital.

## Contract CI/CD Deployments

### ENV Variables

Create a `.env` file with the following variables:

```ini
RPC_URL="<Arbitrum Mainnet RPC>"
REACTIVE_RPC_URL="<Reactive Network RPC>"
PRIVATE_KEY="<Your Deployer Private Key>"

# LeverageLoop Params
POOL="0x794a61358D6845594F94dc1DB02A252b5b4814aD" # Aave V3 Pool (Arbitrum)
COLLATERAL="0x82aF49447D8a07e3bd95BD0d56f35241523fBab1" # WETH (Arbitrum)
DEBT_ASSET="0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f" # WBTC (Arbitrum)
SWAP_ROUTER="0xE592427A0AEce92De3Edee1F18E0157C05861564" # Uniswap V3 Router
TARGET_HF="1500000000000000000" # 1.5 Health Factor
BORROW_RATIO="500000000000000000" # 50% Borrow Ratio (0.5)

# Reactive Params
CHAIN_ID="42161" # Origin Chain ID (Arbitrum One)
LOOP_ADDRESS="<Deployed LeverageLoop Address>"
TARGET_COLLATERAL="1000000000000000000" # 1 ETH Target
TARGET_DEBT="0" # Min Debt
```

### Steps

#### 1. Deploy Leverage Loop (Origin Chain)
Deploy the vault contract to the origin chain (e.g., Arbitrum).

```bash
make deploy-looper
```

*From the output, copy the deployed `LeverageLoop` contract address and update usage in `.env` as `LOOP_ADDRESS`.*

#### 2. Deploy Reactive Contract (Reactive Network)
Deploy the reactive listener to the Reactive Network.

```bash
make deploy-reactive
```

This contract will auto-subscribe to the events from your `LeverageLoop` contract.

## Testing

Run the test suite to verify the repayment and withdrawal logic (simulating full lifecycle).

```bash
make test-repayAndWithdraw
```

Check other looping tests:

```bash
make test-loop
```