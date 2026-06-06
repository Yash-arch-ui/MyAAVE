//SPDX-License-Identifier: MIT 
pragma solidity ^0.8.19;

interface IFlashLoanReceiver{
    function executeOperation(
       address asset,
        uint245 amount,
        address sender,
         uint256 premium,
        address initiator,
        bytes calldata params) external returns (bool);
    }
    
