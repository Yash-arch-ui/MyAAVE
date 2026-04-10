// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AAVE is ERC20 {
    using SafeERC20 for IERC20;

    address public asset;
    uint256 public totalLiquidity;
    uint256 public totalBorrowed;
    uint256 public liquidityIndex;
    uint256 public lastIndexUpdate;

    uint256 public constant OPTIMAL_UTILIZATION = 80e16;
    uint256 public constant BASE_RATE = 2e16;
    uint256 public constant SLOPE1 = 5e16;
    uint256 public constant SLOPE2 = 20e16;

    uint256 public constant LTV = 75;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    mapping(address => uint256) public userBorrowings;
    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public scaledBalances;

    event Supplied(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        uint256 repayAmount,
        uint256 collateralGiven
    );

    constructor(address token) ERC20("TCoin", "aTC") {
        asset = token;
        liquidityIndex = 1e27;
        lastIndexUpdate = block.timestamp;
    }

    function updateLiquidityIndex() internal {
        uint256 timeElapsed = block.timestamp - lastIndexUpdate;
        if (timeElapsed == 0) return;

        uint256 rate = getBorrowRate();
        uint256 interest = (liquidityIndex * rate * timeElapsed) / (365 days * 1e18);
        liquidityIndex += interest;
        lastIndexUpdate = block.timestamp;
    }

    function _accrueInterest(address user) internal {
        uint256 timeElapsed = block.timestamp - lastUpdate[user];
        if (timeElapsed > 0 && userBorrowings[user] > 0) {
            uint256 borrowRate = getBorrowRate();
            uint256 interest = (userBorrowings[user] * borrowRate * timeElapsed) / (365 days * 1e18);
            userBorrowings[user] += interest;
            totalBorrowed += interest;
        }
        lastUpdate[user] = block.timestamp;
    }

    function supply(uint256 amount) external {
        updateLiquidityIndex();

        require(amount > 0, "Amount must be > 0");

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        totalLiquidity += amount;

        uint256 scaledAmount = (amount * 1e27) / liquidityIndex;
        scaledBalances[msg.sender] += scaledAmount;
        _mint(msg.sender, scaledAmount);

        emit Supplied(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        _accrueInterest(msg.sender);

        uint256 collateral = getActualBalance(msg.sender);
        require(collateral > 0, "No collateral");

        uint256 existingBorrow = userBorrowings[msg.sender];
        uint256 maxBorrow = (collateral * LTV) / 100;
        require(existingBorrow + amount <= maxBorrow, "Exceeds max borrow");

        require(getHealthFactor(msg.sender) > 1e18, "Health factor too low");
        require(totalLiquidity - totalBorrowed >= amount, "Insufficient liquidity");

        userBorrowings[msg.sender] += amount;
        totalBorrowed += amount;

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        _accrueInterest(msg.sender);

        uint256 currentDebt = userBorrowings[msg.sender];
        require(currentDebt > 0, "No debt to repay");

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);
        userBorrowings[msg.sender] -= repayAmount;
        totalBorrowed -= repayAmount;
        totalLiquidity += repayAmount;

        emit Repay(msg.sender, repayAmount);
    }

    function withdraw(uint256 amount) external {
        updateLiquidityIndex();

        require(amount > 0, "Amount must be > 0");
        require(getActualBalance(msg.sender) >= amount, "Insufficient balance");

        _accrueInterest(msg.sender);

        uint256 currentDebt = userBorrowings[msg.sender];
        if (currentDebt > 0) {
            uint256 newCollateral = getActualBalance(msg.sender) - amount;
            require(
                (newCollateral * LIQUIDATION_THRESHOLD * 1e18) / (currentDebt * 100) > 1e18,
                "Withdrawal would undercollateralize"
            );
        }

        uint256 scaledAmount = (amount * 1e27) / liquidityIndex;
        scaledBalances[msg.sender] -= scaledAmount;
        totalLiquidity -= amount;

        _burn(msg.sender, scaledAmount);
        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    // user    = the BORROWER being liquidated (unhealthy account)
    // msg.sender = the LIQUIDATOR (pays debt, receives collateral
    
    function liquidate(address user, uint256 repayAmount) external {
        updateLiquidityIndex();
        _accrueInterest(user);                                         

        require(getHealthFactor(user) < 1e18, "HF must be below 1"); 

        if (repayAmount > userBorrowings[user]) {
            repayAmount = userBorrowings[user];                      
        }

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount); 
        userBorrowings[user] -= repayAmount;                     
        totalBorrowed -= repayAmount;
        uint256 collateralToGive = (repayAmount * 110) / 100;         
        uint256 actualBalance = getActualBalance(user);               
        if (collateralToGive > actualBalance) {
            collateralToGive = actualBalance;
        }

        uint256 scaledToRemove = (collateralToGive * 1e27) / liquidityIndex;
        scaledBalances[user] -= scaledToRemove;                       
        totalLiquidity -= collateralToGive;

        _burn(user, scaledToRemove);                                   
        IERC20(asset).safeTransfer(msg.sender, collateralToGive);      

        emit Liquidated(user, msg.sender, repayAmount, collateralToGive);
    }

    function getUtilization() public view returns (uint256) {
        if (totalLiquidity == 0) return 0;
        return (totalBorrowed * 1e18) / totalLiquidity;
    }

    function getBorrowRate() public view returns (uint256) {
        uint256 util = getUtilization();
        if (util <= OPTIMAL_UTILIZATION) {
            return BASE_RATE + (util * SLOPE1) / OPTIMAL_UTILIZATION;
        } else {
            uint256 excess = util - OPTIMAL_UTILIZATION;
            return BASE_RATE + SLOPE1 + (excess * SLOPE2) / (1e18 - OPTIMAL_UTILIZATION);
        }
    }

    // Takes an address so it can check ANY user (needed for liquidate, borrow, withdraw)
    function getHealthFactor(address user) public view returns (uint256) {
        uint256 collateral = getActualBalance(user);
        uint256 debt = userBorrowings[user];
        if (debt == 0) return type(uint256).max;
        return (collateral * LIQUIDATION_THRESHOLD * 1e18) / (debt * 100);
    }

    // Takes an address so it can check ANY user's balance
    function getActualBalance(address user) public view returns (uint256) {
        return (scaledBalances[user] * liquidityIndex) / 1e27;
    }
}