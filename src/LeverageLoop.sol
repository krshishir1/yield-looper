// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ILooper.sol";
import {ReserveConfiguration} from "./libraries/ReserveConfig.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract LeverageLoop {
    using ReserveConfiguration for ReserveConfigurationMap;

    error InvalidAmount();
    error InvalidAsset();
    event LeverageLoop(uint256 collateral, uint256 debt, uint256 hf);

    IPool public immutable pool;

    IERC20 public immutable collateral; // WETH
    IERC20 public immutable debtAsset; // WBTC
    uint256 public immutable collateralDecimals;
    uint256 public immutable debtDecimals;
    uint256 public immutable targetHf;
    uint256 public immutable borrowRatio;

    uint256 public latestHealthFactor;

    ISwapRouter public immutable swapRouter; // Added swapRouter

    constructor(
        address _pool,
        address _collateral,
        address _debtAsset,
        address _swapRouter,
        uint256 _targetHf,
        uint256 _borrowRatio
    ) {
        pool = IPool(_pool);
        collateral = IERC20(_collateral);
        debtAsset = IERC20(_debtAsset);
        collateralDecimals = IERC20Metadata(_collateral).decimals();
        debtDecimals = IERC20Metadata(_debtAsset).decimals();
        swapRouter = ISwapRouter(_swapRouter);
        targetHf = _targetHf;
        borrowRatio = _borrowRatio;
    }

    // Added _swap internal function
    function tokenSwap(uint256 amountIn) public returns (uint256 amountOut) {
        if (amountIn > debtAsset.balanceOf(address(this))) {
            amountIn = debtAsset.balanceOf(address(this));
        }

        debtAsset.approve(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(debtAsset),
                tokenOut: address(collateral),
                fee: 500, // 0.05% fee tier, common for WETH/WBTC
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
    }

    function supplyAndBorrow(uint256 amount) public {
        collateral.transferFrom(msg.sender, address(this), amount);

        collateral.approve(address(pool), amount);
        pool.supply(address(collateral), amount, address(this), 0);

        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );

        // Getting available borrow power
        (, , uint256 availableBorrowsBase, , , ) = pool.getUserAccountData(
            address(this)
        );

        // console.log("Available Borrows Base", availableBorrowsBase);

        uint256 borrowAmountBase = (availableBorrowsBase * borrowRatio) / 1e18; // 20000 usd
        uint256 debtPrice = oracle.getAssetPrice(address(debtAsset)); // 100000 usd
        uint256 borrowAmt = (borrowAmountBase * (10 ** debtDecimals)) /
            debtPrice;

        latestHealthFactor = previewHealthFactor(0, borrowAmt);
        console.log(
            "Preview Health Factor: ",
            previewHealthFactor(0, borrowAmt)
        );

        if (latestHealthFactor > targetHf) {
            pool.borrow(address(debtAsset), borrowAmt, 2, 0, address(this));
            emit LeverageLoop(
                getTotalCollateral(),
                getTotalDebt(),
                getHealthFactor()
            );
        } else {
            console.log("Health factor too low. Borrow skipped");
        }
    }

    function repay(uint256 amount) public {
        console.log("Repaying", amount);
        debtAsset.approve(address(pool), amount);
        pool.repay(address(debtAsset), amount, 2, address(this));
    }

    function withdraw(uint256 amount, address to) public {
        pool.withdraw(address(collateral), amount, to);
    }

    function reinvest(
        address /* sender */,
        uint256 borrowAmountBase,
        bool resume
    ) public {
        if (!resume) {
            return;
        }

        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );
        uint256 debtPrice = oracle.getAssetPrice(address(debtAsset));
        uint256 borrowAmount = (borrowAmountBase * (10 ** debtDecimals)) /
            debtPrice;

        uint256 amount = tokenSwap(borrowAmount - 1);

        supplyAndBorrow(amount);
    }

    function repayAndWithdrawFunds(
        address sender,
        address collateralAddress,
        address debtAddress
    ) public {
        if (collateralAddress != address(collateral)) {
            revert InvalidAsset();
        }

        if (debtAddress != address(debtAsset)) {
            revert InvalidAsset();
        }

        repay(debtAsset.balanceOf(address(this)));

        uint256 amountBase = getTotalCollateral() - getTotalDebt() * 2;
        uint256 withdrawAmount = convertToToken(collateralAddress, amountBase);

        withdraw(withdrawAmount, sender);
    }

    // Getter functions

    function previewHealthFactor(
        uint256 amountCollateral,
        uint256 amountDebt
    ) public view returns (uint256) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            uint256 currentLT,
            ,

        ) = pool.getUserAccountData(address(this));

        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );

        uint256 collateralPrice = oracle.getAssetPrice(address(collateral)); // WETH
        uint256 debtPrice = oracle.getAssetPrice(address(debtAsset)); // WBTC

        uint256 collateralAmountBase = (amountCollateral * collateralPrice) /
            (10 ** collateralDecimals);
        uint256 debtAmountBase = (amountDebt * debtPrice) /
            (10 ** debtDecimals);

        uint256 totalCollateral = totalCollateralBase + collateralAmountBase;
        uint256 totalDebt = totalDebtBase + debtAmountBase;

        ReserveConfigurationMap memory config = pool.getConfiguration(
            address(collateral)
        );
        (, uint256 collateralLT, , , ) = config.getParams();

        if (totalCollateralBase == 0) {
            uint256 hf = (collateralAmountBase * collateralLT * 1e14) /
                totalDebt;
            // *1e14 converts LT from bps (1e4) to 1e18 HF scaling
            return hf;
        }

        uint256 newWeightedLT = ((totalCollateralBase * currentLT) +
            (collateralAmountBase * collateralLT)) /
            (totalCollateralBase + collateralAmountBase);

        uint256 hf = (totalCollateral * newWeightedLT * 1e14) / totalDebt;

        return hf;
    }

    function getAPYData(
        address token
    ) public view returns (uint256 supplyAPY, uint256 borrowAPY) {
        ReserveData memory data = IPool(pool).getReserveData(token);

        supplyAPY = data.currentLiquidityRate;
        borrowAPY = data.currentVariableBorrowRate;
    }

    function getHealthFactor() public view returns (uint256) {
        (, , , , , uint256 hf) = pool.getUserAccountData(address(this));
        return hf;
    }

    function getTotalCollateral() public view returns (uint256) {
        (uint256 totalCollateralBase, , , , , ) = pool.getUserAccountData(
            address(this)
        );
        return totalCollateralBase;
    }

    function getTotalDebt() public view returns (uint256) {
        (, uint256 totalDebtBase, , , , ) = pool.getUserAccountData(
            address(this)
        );
        return totalDebtBase;
    }

    function getCollateralAmount() public view returns (uint256) {
        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );
        (uint256 totalCollateralBase, , , , , ) = pool.getUserAccountData(
            address(this)
        );
        uint256 collateralPrice = oracle.getAssetPrice(address(collateral));
        return
            (totalCollateralBase * (10 ** collateralDecimals)) /
            collateralPrice;
    }

    function getBorrowAmount() public view returns (uint256) {
        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );
        (, uint256 totalDebtBase, , , , ) = pool.getUserAccountData(
            address(this)
        );
        uint256 debtPrice = oracle.getAssetPrice(address(debtAsset));
        return (totalDebtBase * (10 ** debtDecimals)) / debtPrice;
    }

    function convertToBase(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );
        uint256 price = oracle.getAssetPrice(token);
        uint256 decimals = IERC20Metadata(token).decimals();
        return (amount * price) / (10 ** decimals);
    }

    function convertToToken(
        address token,
        uint256 amountBase
    ) public view returns (uint256) {
        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );
        uint256 price = oracle.getAssetPrice(token);
        uint256 decimals = IERC20Metadata(token).decimals();
        return (amountBase * (10 ** decimals)) / price;
    }

    function getLatestHealthFactor() public view returns (uint256) {
        return latestHealthFactor;
    }
}
