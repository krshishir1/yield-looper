// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LeverageLoop} from "../src/LeverageLoop.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interfaces/ILooper.sol";

contract LeverageLoopTest is Test {
    // Pool on Arbitrum
    address constant pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    // WETH Arbitrum
    address constant collateralToken =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // WBTC Arbitrum
    address constant debtToken = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    uint256 constant SAFE_HEALTH_FACTOR = 13e17;
    uint256 constant MAX_LOOPS = 10;
    uint256 constant USER_BALANCE = 0.1 ether;
    uint256 constant BORROW_RATIO = 50e16; // 50%

    address user = vm.addr(1);

    LeverageLoop loop;

    // Router for Arbitrum
    address constant swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function setUp() public {
        loop = new LeverageLoop(
            pool,
            collateralToken,
            debtToken,
            swapRouter,
            SAFE_HEALTH_FACTOR,
            BORROW_RATIO
        );

        deal(collateralToken, user, USER_BALANCE);

        console.log(address(loop));
        console.log(IERC20(collateralToken).balanceOf(user));
        console.log(IERC20(debtToken).balanceOf(user));
    }

    function testSupplyAndBorrowAPY() public {
        (uint256 collateral_supplyAPY, uint256 collateral_borrowAPY) = loop
            .getAPYData(collateralToken);
        (uint256 debt_supplyAPY, uint256 debt_borrowAPY) = loop.getAPYData(
            debtToken
        );

        console.log(collateral_supplyAPY);
        console.log(debt_borrowAPY);

        uint256 amount = 0.0032 ether;
        uint256 borrowRatio = 30e16;

        console.log("Intial amount: ", amount);

        if (collateral_supplyAPY > debt_borrowAPY) {
            uint256 index = 0;

            vm.startPrank(user);
            IERC20(collateralToken).approve(address(loop), type(uint256).max);

            do {
                if (index > 0) {
                    uint256 borrowAmtToSwap = loop.getBorrowAmount();
                    amount = loop.tokenSwap(borrowAmtToSwap - 1);
                }

                loop.supplyAndBorrow(amount); // 35010

                console.log("Collateral amount: ", loop.getTotalCollateral());
                console.log("Debt amount: ", loop.getTotalDebt());

                // vm.warp(block.timestamp + 30 days);

                // console.log("Collateral amount: ", loop.getTotalCollateral());
                // console.log("Debt amount: ", loop.getTotalDebt());

                console.log("Health factor: ", loop.getHealthFactor());

                index++;
            } while (
                (loop.getLatestHealthFactor() > SAFE_HEALTH_FACTOR) &&
                    (index < MAX_LOOPS)
            );

            vm.stopPrank();
        }

        vm.warp(block.timestamp + 365 days);

        console.log("\n After 30 days\n");

        console.log("Collateral amount: ", loop.getTotalCollateral());
        console.log("Debt amount: ", loop.getTotalDebt());
        console.log("Health factor: ", loop.getHealthFactor());

        loop.repay(loop.getBorrowAmount());

        uint256 withdrawAmount = type(uint256).max;
        vm.startPrank(user);
        loop.withdraw(withdrawAmount, user);
        vm.stopPrank();

        uint256 finalAmount = IERC20(collateralToken).balanceOf(user);
        console.log("User Collateral Amount: ", finalAmount);

        int256 profitMade = int256(finalAmount) - int256(USER_BALANCE);
        console.log("Profit Made: ", profitMade);

        // console.log("Supply APY:", supplyAPY);
        // console.log("Borrow APY:", borrowAPY);
    }

    function testTokenSwap() public {
        uint256 amountIn = 10e8; // 1 WBTC
        deal(debtToken, address(loop), amountIn);

        uint256 balanceBefore = IERC20(collateralToken).balanceOf(
            address(loop)
        );
        console.log("Collateral Balance Before:", balanceBefore);

        loop.tokenSwap(amountIn);

        uint256 balanceAfter = IERC20(collateralToken).balanceOf(address(loop));
        console.log("Collateral Balance After:", balanceAfter);

        assertTrue(balanceAfter > balanceBefore);
    }

    function testRepays() public {
        uint256 amount = USER_BALANCE;

        vm.startPrank(user);
        IERC20(collateralToken).approve(address(loop), amount);
        loop.supplyAndBorrow(amount);
        vm.stopPrank();

        uint256 debtBefore = loop.getBorrowAmount();
        console.log("Debt Before Repay (Token Amount):", debtBefore);

        loop.repay(debtBefore);

        uint256 debtAfter = loop.getBorrowAmount();
        console.log("Debt After Repay (Token Amount):", debtAfter);

        // Assert debt is zero (or extremely close due to dust, but getBorrowAmount should be 0 if repay(max) logic worked)
        // assertEq(debtAfter, 0, "Debt should be zero after full repay");
    }

    function testRepayAndWithdraw() public {
        uint256 amount = USER_BALANCE;

        vm.startPrank(user);
        IERC20(collateralToken).approve(address(loop), amount);
        loop.supplyAndBorrow(amount);

        console.log("Debt Amount: ", loop.getBorrowAmount());
        console.log("Collateral Amount: ", loop.getCollateralAmount());

        loop.repayAndWithdrawFunds(user, collateralToken, debtToken);

        console.log("Debt Amount: ", loop.getBorrowAmount());
        console.log("Collateral Amount: ", loop.getCollateralAmount());

        vm.stopPrank();
    }
}

// 10 ether => 30000$

// 20393582812728229742625316
// 67326098780344564750905017
// 296566984659896010587153
// 8492220060808803254580524
// 17579742382148764971324025
// 23706797584423175049254193

// 3088351487199
// 1853010968196
