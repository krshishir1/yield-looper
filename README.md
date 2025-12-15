This project is about creating a looping strategy for lending protocol. It involves the usage of Reactive Network to properly handle the recurring lending and borrowing operations.

Conditions for looping:
1. borrowAPR + slippage > supplyAPR
2. currentLTV >= targetLTV
3. healthFactor > 1.5

( totalCollateralUSD,
  totalDebtUSD,
  , , ltv, healthFactor
) = pool.getUserAccountData(address(this));

bool profitable = supplyAPR > (borrowAPR + slippage + gasCost);
bool healthy    = healthFactor > 1.5;
bool belowLTV   = currentLTV < targetLTV;