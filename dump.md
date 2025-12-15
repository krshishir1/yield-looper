    function loop(
        uint256 amount,
        uint256 iterations,
        uint256 borrowRatio // 1e18 = 100% of available borrow power
    ) external {
        collateral.transferFrom(msg.sender, address(this), amount);

        collateral.approve(address(pool), amount);
        pool.supply(address(collateral), amount, address(this), 0);

        IPriceOracle oracle = IPriceOracle(
            pool.ADDRESSES_PROVIDER().getPriceOracle()
        );

        for (uint i = 0; i < iterations; i++) {
            // Changed loop condition to use 'iterations'
            // Get available borrow power in Base Currency (USD 8 decimals usually)
            (, , uint256 availableBorrowsBase, , , ) = pool.getUserAccountData(
                address(this)
            );

            console.log("Available Borrows Base", availableBorrowsBase);

            // Apply safety factor (borrowRatio)
            uint256 borrowAmountBase = (availableBorrowsBase * borrowRatio) /
                1e18;

            console.log("Borrow Amount Base", borrowAmountBase);

            // Convert Base -> Debt Units
            // Asset Price is in Base Currency (usually 8 decimals for USD)
            uint256 debtPrice = oracle.getAssetPrice(address(debtAsset));
            console.log("Debt Price", debtPrice);
            // borrowAmountBase (8 dec) * 10^debtDecimals / debtPrice (8 dec) = debtUnits
            // Assumes Base is 8 decimals (Aave V3 standard).
            uint256 borrowAmt = (borrowAmountBase * (10 ** debtDecimals)) /
                debtPrice;

            console.log("Borrow Amount", borrowAmt);

            pool.borrow(address(debtAsset), borrowAmt, 2, 0, address(this));

            // Replaced mocked swap logic with _swap call
            // Swap Debt -> Collateral
            // Swap Debt -> Collateral
            uint256 nextCollateralAmt = tokenSwap(
                address(debtAsset),
                address(collateral),
                borrowAmt
            );

            console.log("Next Collateral Amount (Swapped)", nextCollateralAmt);

            collateral.approve(address(pool), nextCollateralAmt);
            pool.supply(
                address(collateral),
                nextCollateralAmt,
                address(this),
                0
            );
        }
    }