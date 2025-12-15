include .env

NETWORK_ARGS := --fork-url $(RPC_URL) 

test-loop:
	forge test test/LeverageLoop.t.sol $(NETWORK_ARGS) -vvv

test-reserveData:
	forge test test/LeverageLoop.t.sol --mt testReserveData $(NETWORK_ARGS) -vvv

test-supplyAndBorrowAPY:
	forge test test/LeverageLoop.t.sol --mt testSupplyAndBorrowAPY $(NETWORK_ARGS) -vvv

test-tokenSwap:
	forge test test/LeverageLoop.t.sol --mt testTokenSwap $(NETWORK_ARGS) -vvv

test-repayAndWithdraw:
	forge test test/LeverageLoop.t.sol --mt testRepayAndWithdraw $(NETWORK_ARGS) -vvv

test-repay:
	forge test test/LeverageLoop.t.sol --mt testRepays $(NETWORK_ARGS) -vvv

deploy-looper:
	forge create src/LeverageLoop.sol:LeverageLoop \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--constructor-args $(POOL) $(COLLATERAL) $(DEBT_ASSET) $(SWAP_ROUTER) $(TARGET_HF) $(BORROW_RATIO) \
		--broadcast

deploy-reactive:
	forge create src/libraries/LeverageLoopReactive.sol:LeverageLoopReactive \
		--rpc-url $(REACTIVE_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--constructor-args $(CHAIN_ID) $(LOOP_ADDRESS) $(TARGET_COLLATERAL) $(TARGET_DEBT) $(TARGET_HF) \
		--broadcast
