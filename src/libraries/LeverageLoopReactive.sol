// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "@reactive/contracts/interfaces/IReactive.sol";
import "@reactive/contracts/abstract-base/AbstractPausableReactive.sol";

contract LeverageLoopReactive is IReactive, AbstractPausableReactive {
    // cast keccak256 "LeverageLoop(uint256,uint256,uint256)"
    uint256 private constant LEVERAGE_LOOP_TOPIC0 =
        0x7648598be48ea31e0e5dd4d34a358c4a083f51d78cac29c798b68c7ec3e4910a;

    // cast keccak "LiquidationCall(address,address,address,uint256,uint256,address,bool)"
    uint256 private constant LIQUIDATION_CALL_TOPIC0 =
        0xe413a321e8681d831f4dbccbca790d2952b56f977908e45be37335533e005286;

    address private immutable i_looper;
    uint256 private immutable i_chainid;
    uint256 private immutable i_targetCollateral;
    uint256 private immutable i_targetDebt;
    uint256 private immutable i_targetHf;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    constructor(
        uint256 _chainid,
        address _loopAddress,
        uint256 _targetCollateral,
        uint256 _targetDebt,
        uint256 _targetHf
    ) payable {
        i_looper = _loopAddress;
        i_chainid = _chainid;
        i_targetCollateral = _targetCollateral;
        i_targetDebt = _targetDebt;
        i_targetHf = _targetHf;

        owner = msg.sender;

        if (!vm) {
            service.subscribe(
                _chainid,
                _loopAddress,
                LEVERAGE_LOOP_TOPIC0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                _chainid,
                _loopAddress,
                LIQUIDATION_CALL_TOPIC0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    function getPausableSubscriptions()
        internal
        view
        override
        returns (Subscription[] memory)
    {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            i_chainid,
            i_looper,
            LEVERAGE_LOOP_TOPIC0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    function react(LogRecord calldata log) external vmOnly {
        if (log.chain_id != i_chainid) {
            return;
        }

        if (log.topic_0 == LEVERAGE_LOOP_TOPIC0 && log._contract == i_looper) {
            uint256 totalCollateralBase = log.topic_1;
            uint256 totalDebtBase = log.topic_2;
            uint256 healthFactor = abi.decode(log.data, (uint256));

            if (
                totalCollateralBase >= i_targetCollateral &&
                totalDebtBase >= i_targetDebt &&
                healthFactor >= i_targetHf
            ) {
                bytes memory payload = abi.encodeWithSignature(
                    "reinvest(address,uint256,bool)",
                    address(0),
                    totalDebtBase,
                    true
                );

                emit Callback(
                    log.chain_id,
                    i_looper,
                    CALLBACK_GAS_LIMIT,
                    payload
                );
            }
        }

        if (log.topic_0 == LIQUIDATION_CALL_TOPIC0) {
            address collateralAsset = address(uint160(uint256(log.topic_1)));
            address debtAsset = address(uint160(uint256(log.topic_2)));
            address user = address(uint160(uint256(log.topic_3)));

            if (user != i_looper) {
                return;
            }

            bytes memory payload = abi.encodeWithSignature(
                "repayAndWithdrawFunds(address,address,address)",
                owner,
                collateralAsset,
                debtAsset
            );

            emit Callback(log.chain_id, i_looper, CALLBACK_GAS_LIMIT, payload);
        }
    }
}
