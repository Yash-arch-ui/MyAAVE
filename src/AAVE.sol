// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AAVE is ERC20 {
    using SafeERC20 for IERC20;

    address public asset;

    uint256 public totalLiquidity;
    uint256 public totalBorrowed;
    uint256 public interestRate = 5;

    uint256 public constant LTV = 75;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public userBorrowings;
    mapping(address => uint256) public lastUpdate;

    event Supplied(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);

    constructor(address token) ERC20("TCoin", "aTC") {
        asset = token;
    }

    function _accrueInterest(address user) internal {
        uint256 timeElapsed = block.timestamp - lastUpdate[user];
        if (timeElapsed > 0 && userBorrowings[user] > 0) {
            uint256 interest = (userBorrowings[user] * interestRate * timeElapsed) / (365 days * 100);
            userBorrowings[user] += interest;
            totalBorrowed += interest;
        }
        lastUpdate[user] = block.timestamp;
    }

    function supply(uint256 amount, address user) external {
        require(amount > 0);
        require(user != address(0));

        IERC20(asset).safeTransferFrom(user, address(this), amount);

        totalLiquidity += amount;
        userBalance[user] += amount;

        _mint(user, amount);

        emit Supplied(user, amount);
    }

    function borrow(uint256 amount, address user) external {
        require(amount > 0);
        require(user != address(0));

        _accrueInterest(user);

        uint256 collateral = userBalance[user];
        require(collateral > 0);

        uint256 existingBorrow = userBorrowings[user];
        uint256 maxBorrow = (collateral * LTV) / 100;

        require(existingBorrow + amount <= maxBorrow);

        uint256 newDebt = existingBorrow + amount;
        uint256 healthFactor = getHealthFactor(collateral, newDebt);

        require(healthFactor > 1);
        require(totalLiquidity - totalBorrowed >= amount);

        userBorrowings[user] += amount;
        totalBorrowed += amount;

        IERC20(asset).safeTransfer(user, amount);

        emit Borrow(user, amount);
    }

    function repay(uint256 amount, address user) external {
        require(amount > 0);
        require(user != address(0));

        _accrueInterest(user);

        uint256 currentDebt = userBorrowings[user];
        require(currentDebt > 0);

        uint256 repayAmount = amount;
        if (amount > currentDebt) {
            repayAmount = currentDebt;
        }

        IERC20(asset).safeTransferFrom(user, address(this), repayAmount);

        userBorrowings[user] -= repayAmount;
        totalBorrowed -= repayAmount;
        totalLiquidity += repayAmount;

        emit Repay(user, repayAmount);
    }

    function withdraw(uint256 amount, address user) external {
        require(amount > 0);
        require(user != address(0));

        _accrueInterest(user);

        uint256 collateral = userBalance[user];
        require(collateral >= amount);

        uint256 currentDebt = userBorrowings[user];

        if (currentDebt == 0) {
            userBalance[user] -= amount;
            totalLiquidity -= amount;

            _burn(user, amount);
            IERC20(asset).safeTransfer(user, amount);
            return;
        }

        uint256 newCollateral = collateral - amount;
        uint256 healthFactor = getHealthFactor(newCollateral, currentDebt);

        require(healthFactor > 1);

        userBalance[user] -= amount;
        totalLiquidity -= amount;

        _burn(user, amount);
        IERC20(asset).safeTransfer(user, amount);
    }

    function liquidate(address user, uint256 repayAmount) external {
        _accrueInterest(user);

        require(
            getHealthFactor(userBalance[user], userBorrowings[user]) < 1e18,
            "HF must be below 1"
        );

        if (repayAmount > userBorrowings[user]) {
            repayAmount = userBorrowings[user];
        }

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);

        userBorrowings[user] -= repayAmount;
        totalBorrowed -= repayAmount;

        uint256 collateralToGive = (repayAmount * 110) / 100;
        if (collateralToGive > userBalance[user]) {
            collateralToGive = userBalance[user];
        }

        userBalance[user] -= collateralToGive;
        totalLiquidity -= collateralToGive;

        IERC20(asset).safeTransfer(msg.sender, collateralToGive);
    }

    function getHealthFactor(
        uint256 collateralValue,
        uint256 totalBorrowedValue
    ) public pure returns (uint256) {
        if (totalBorrowedValue == 0) return type(uint256).max;

        return (collateralValue * LIQUIDATION_THRESHOLD * 1e18) /
            (totalBorrowedValue * 100);
    }
}