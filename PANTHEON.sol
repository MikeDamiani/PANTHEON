//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PANTHEON is ERC20Burnable, Ownable2Step, ReentrancyGuard {

    error ZeroAddressNotAllowed();
    
    address payable private FEE_ADDRESS;                                        

    uint256 public constant MIN = 1000;                                                                               

    uint256 public totalEth = msg.value;
 
    uint16 public REDEEM_FEE = 900;
    uint16 public MINT_FEE = 900;
    uint16 public constant FEE_BASE_1000 = 1000;

    uint8 public constant FEES = 25;

    uint128 public constant ETHinWEI = 1 * 10 ** 18;

    event Price(uint256 time, uint256 recieved, uint256 sent);
    event MaxUpdated(uint256 max);
    event RedeemFeeUpdated(uint256 redeemFee);
    event MintFeeUpdated(uint256 mintFee);

    constructor(address _feeAddress) payable ERC20("Pantheon", "PANTHEON") {
        if(_feeAddress == address(0)) revert ZeroAddressNotAllowed();
        
        _mint(msg.sender, msg.value * MIN);
        totalEth = msg.value;

        FEE_ADDRESS = payable(_feeAddress);

        transfer(0x000000000000000000000000000000000000dEaD, 10000);
    }

    function setFeeAddress(address _address) external onlyOwner {
        require(_address != address(0x0));
        FEE_ADDRESS = payable(_address);
    }

    function redeem(uint256 pantheon) external nonReentrant {
        require(pantheon > MIN, "must trade over min");

        // Total Eth to be sent
        uint256 eth = PANTHEONtoETH(pantheon);

        // Burn of PANTHEON
        _burn(msg.sender, pantheon);

        // Payment to sender
        uint256 ethToSender = (eth * REDEEM_FEE) / FEE_BASE_1000;
        sendEth(msg.sender, ethToSender);

        // Team fee
        uint256 ethToFeeAddress = eth / FEES;
        sendEth(FEE_ADDRESS, ethToFeeAddress);

        totalEth -= (ethToSender + ethToFeeAddress);

        emit Price(block.timestamp, pantheon, eth);
    }
    
    function mint(address reciever) external payable nonReentrant {
        require(msg.value > MIN, "must trade over min");

        // Mint Pantheon to sender
        uint256 pantheon = ETHtoPANTHEON(msg.value);
        _mint(reciever, (pantheon * MINT_FEE) / FEE_BASE_1000);

        // Team fee
        uint256 ethToFeeAddress = msg.value / FEES;
        sendEth(FEE_ADDRESS, ethToFeeAddress);

        totalEth += (msg.value - ethToFeeAddress);

        emit Price(block.timestamp, pantheon, msg.value);
    }

    function PANTHEONtoETH(uint256 value) public view returns (uint256) {
        return (value * totalEth) / totalSupply();
    }

    function ETHtoPANTHEON(uint256 value) public view returns (uint256) {
        return (value * totalSupply()) / (totalEth);
    }

    function sendEth(address _address, uint256 _value) internal {
        (bool success, ) = _address.call{value: _value}("");
        require(success, "ETH Transfer failed.");
    }

    function getMintPantheon(uint256 amount) external view returns (uint256) {
        return
            (amount * (totalSupply()) * (MINT_FEE)) /
            (totalEth) /
            (FEE_BASE_1000);
    }

    function getRedeemPantheon(uint256 amount) external view returns (uint256) {
        return
            ((amount * totalEth) * (REDEEM_FEE)) /
            (totalSupply()) /
            (FEE_BASE_1000);
    }

    function getTotalEth() external view returns (uint256) {
        return totalEth;
    }

    function emergencyFixTotalEth() external onlyOwner nonReentrant {
        totalEth = address(this).balance;
    }

    receive() external payable {
        totalEth += msg.value;
    }
}