//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PANTHEON is ERC20Burnable, Ownable2Step, ReentrancyGuard {

    error ZeroAddressNotAllowed();
    error MustTradeOverMin();
    error EthTransferFailed();
    
    address payable private FEE_ADDRESS;                                        

    uint256 private constant _MIN = 1000;                                                                               

    uint256 public totalEth;
 
    uint16 private constant _MINT_AND_REDEEM_FEE = 900;
    uint16 private constant _FEE_BASE_1000 = 1000;

    uint8 private constant _FEES = 25;

    event PriceAfterMint(uint256 time, uint256 recieved, uint256 sent);
    event PriceAfterRedeem(uint256 time, uint256 recieved, uint256 sent);
    event FeeAddressUpdated(address newFeeAddress);
    event totalEthFixed(uint256 totalEthEmergencyFixed);

    constructor(address _feeAddress) payable ERC20("Pantheon", "PANTHEON") {
        if(_feeAddress == address(0)) revert ZeroAddressNotAllowed();
        
        _mint(msg.sender, msg.value * _MIN);
        totalEth = msg.value;

        FEE_ADDRESS = payable(_feeAddress);

        transfer(0x000000000000000000000000000000000000dEaD, 10000);
    }

    receive() external payable {
        totalEth += msg.value;
    }

    function setFeeAddress(address _address) external onlyOwner {
        assemblyOwnerNotZero(_address); 
        FEE_ADDRESS = payable(_address);

        emit FeeAddressUpdated(_address);
    }

    function redeem(uint256 pantheon) external nonReentrant {
        if(pantheon < _MIN) revert MustTradeOverMin();

        uint256 eth = PANTHEONtoETH(pantheon);

        uint256 ethToFeeAddress = eth / _FEES;
        uint256 ethToSender = (eth * _MINT_AND_REDEEM_FEE) / _FEE_BASE_1000;
        totalEth -= (ethToSender + ethToFeeAddress);

        _burn(msg.sender, pantheon);

        sendEth(FEE_ADDRESS, ethToFeeAddress);

        sendEth(msg.sender, ethToSender);

        emit PriceAfterRedeem(block.timestamp, pantheon, eth);
    }
    
    function mint(address reciever) external payable nonReentrant {
        if(msg.value < _MIN) revert MustTradeOverMin();

        uint256 pantheon = ETHtoPANTHEON(msg.value);

        uint256 ethToFeeAddress = msg.value / _FEES;
        totalEth += (msg.value - ethToFeeAddress);

        sendEth(FEE_ADDRESS, ethToFeeAddress);

        _mint(reciever, (pantheon * _MINT_AND_REDEEM_FEE) / _FEE_BASE_1000);

        emit PriceAfterMint(block.timestamp, pantheon, msg.value);
    }

    function emergencyFixTotalEth() external onlyOwner {
        totalEth = address(this).balance;

        emit totalEthFixed(address(this).balance);
    }

    function sendEth(address _address, uint256 _value) internal {
        (bool success, ) = _address.call{value: _value}("");
        if(success != true) revert EthTransferFailed();
    }

    function PANTHEONtoETH(uint256 value) private view returns (uint256) {
        return (value * totalEth) / totalSupply();
    }

    function ETHtoPANTHEON(uint256 value) private view returns (uint256) {
        return (value * totalSupply()) / (totalEth);
    }

    function getMintPantheon(uint256 amount) external view returns (uint256) {
        return
            (amount * (totalSupply()) * (_MINT_AND_REDEEM_FEE)) /
            (totalEth) /
            (_FEE_BASE_1000);
    }

    function getRedeemPantheon(uint256 amount) external view returns (uint256) {
        return
            ((amount * totalEth) * (_MINT_AND_REDEEM_FEE)) /
            (totalSupply()) /
            (_FEE_BASE_1000);
    }

    function getTotalEth() external view returns (uint256) {
        return totalEth;
    }

    function assemblyOwnerNotZero(address _addr) public pure {
        assembly {
            if iszero(_addr) {
                mstore(0x00 , "Zero address")
                revert(0x00 , 0x20)
            }
        }
    }
}