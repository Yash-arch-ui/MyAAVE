//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;


import "./interface/IFlashLoanReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract FlashBorrower is IFlashLoanReceiver{
    using SafeERC20 for IERC20;

    address public immutable pool;
    constructor (address _pool){
        pool = _pool;
    }
    function executeOperation(address asset, uint256 amount , uint256 fee, address, bytes calldata)
    external override returns(bool){
        require(msg.sender == pool, "Not pool");
        // Arbitrage
        // Liquidation
        // Swaps 

        uint256 repayment = amount + fee;
        require(IERC20(asset).balanceOf(address(this)) >= repayment, "Not enough funds to repay");
        IERC20(asset).safeTransfer(pool, repayment);
        return true;

    }
}