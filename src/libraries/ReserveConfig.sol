// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ILooper.sol";

library ReserveConfiguration {
    uint256 constant LTV_MASK = 0xFFFF;
    uint256 constant LIQUIDATION_THRESHOLD_MASK = 0xFFFF0000;
    uint256 constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 constant LIQUIDATION_BONUS_MASK = 0xFFFF00000000;
    uint256 constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
    uint256 constant DECIMALS_MASK = 0xFF000000000000;
    uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
    uint256 constant RESERVE_FACTOR_MASK = 0xFFFF0000000000000000;
    uint256 constant RESERVE_FACTOR_START_BIT_POSITION = 64;

    function getParams(
        ReserveConfigurationMap memory self
    ) internal pure returns (uint256, uint256, uint256, uint256, uint256) {
        uint256 dataLocal = self.data;

        return (
            dataLocal & LTV_MASK,
            (dataLocal & LIQUIDATION_THRESHOLD_MASK) >>
                LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (dataLocal & LIQUIDATION_BONUS_MASK) >>
                LIQUIDATION_BONUS_START_BIT_POSITION,
            (dataLocal & DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
            (dataLocal & RESERVE_FACTOR_MASK) >>
                RESERVE_FACTOR_START_BIT_POSITION
        );
    }
}
