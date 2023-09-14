//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PANTHEON, Reserve Currency and Store of Value for $ETH
 *
 * @notice The ETH / PANTHEON ratio is designed to appreciate for every mints and redeems that occur.
 * @custom:idea The Idea behind this token model has been inspired by Jaypeggers
 *
 * @author Michael Damiani
 */
contract PANTHEON is ERC20Burnable, Ownable2Step, ReentrancyGuard {
    /**
     * @custom:section                           ** ERRORS **
     */
    error ZeroAddressNotAllowed();
    error MustTradeOverMin();
    error EthTransferFailed();

    /**
     * @custom:section                           ** CONSTANTS **
     */
    uint256 private constant _FEES = 25;
    uint256 private constant _MIN = 1000;
    uint256 private constant _MINT_AND_REDEEM_FEE = 900;
    uint256 private constant _FEE_BASE_1000 = 1000;

    /**
     * @custom:section                           **  STATE VARIABLES **
     */
    uint256 public totalEth;
    address payable public feeAddress;

    /**
     * @custom:section                           ** EVENTS **
     */
    event PriceAfterMint(
        uint256 indexed time,
        uint256 indexed recieved,
        uint256 indexed sent
    );
    event PriceAfterRedeem(
        uint256 indexed time,
        uint256 indexed recieved,
        uint256 indexed sent
    );
    event FeeAddressUpdated(address indexed newFeeAddress);
    event TotalEthFixed(uint256 indexed totalEthEmergencyFixed);

    /**
     * @custom:section                           ** CONSTRUCTOR **
     */
    constructor(address _feeAddress) payable ERC20("Pantheon", "PANTHEON") {
        if (_feeAddress == address(0)) revert ZeroAddressNotAllowed();

        _mint(msg.sender, msg.value * _MIN);
        totalEth = msg.value;

        feeAddress = payable(_feeAddress);

        transfer(0x000000000000000000000000000000000000dEaD, 10000);
    }

    receive() external payable {
        totalEth += msg.value;
    }

    /**
     * @custom:section                           ** EXTERNAL FUNCTIONS **
     */

    /**
     * @param receiver: is the address that will receive the $PANTHEON minted
     * @notice This function is used by users that want to mint $PANTHEON by depositing the corrisponding amount of $ETH + a 10% fee
     * @notice The ETH / PANTHEON ratio will increase after every mint
     */
    function mint(address receiver) external payable nonReentrant {
        if (msg.value < _MIN) revert MustTradeOverMin();

        uint256 pantheon = _ETHtoPANTHEON(msg.value);

        uint256 ethToFeeAddress = msg.value / _FEES;
        totalEth += (msg.value - ethToFeeAddress);

        sendEth(feeAddress, ethToFeeAddress);

        _mint(receiver, (pantheon * _MINT_AND_REDEEM_FEE) / _FEE_BASE_1000);

        emit PriceAfterMint(block.timestamp, pantheon, msg.value);
    }

    /**
     * @param pantheon: is the amount of $PANTHEON that the user want to burn in order to redeem the corrisponding amount of $ETH
     * @notice This function is used by users that want to burn their balance of $PANTHEON and redeem the corrisponding amount of $ETH - a 8.8% fee
     * @notice The ETH / PANTHEON ratio will increase after every redeem
     */
    function redeem(uint256 pantheon) external nonReentrant {
        if (pantheon < _MIN) revert MustTradeOverMin();

        uint256 eth = _PANTHEONtoETH(pantheon);

        uint256 ethToFeeAddress = eth / _FEES;
        uint256 ethToSender = (eth * _MINT_AND_REDEEM_FEE) / _FEE_BASE_1000;
        totalEth -= (ethToSender + ethToFeeAddress);

        _burn(msg.sender, pantheon);

        sendEth(feeAddress, ethToFeeAddress);

        sendEth(msg.sender, ethToSender);

        emit PriceAfterRedeem(block.timestamp, pantheon, eth);
    }

    /**
     * @param _address: The Address that will receive the Liquidty Incentives and Team Fee
     * @notice This function will be used to update the feeAddress
     */
    function setFeeAddress(address _address) external onlyOwner {
        _assemblyOwnerNotZero(_address);
        feeAddress = payable(_address);

        emit FeeAddressUpdated(_address);
    }

    /**
     * @notice This function is used to reflect the correct amount of totalEth in case some unexpected bug occur
     */
    function emergencyFixTotalEth() external onlyOwner {
        totalEth = address(this).balance;

        emit TotalEthFixed(address(this).balance);
    }

    /**
     * @custom:section                           ** INTERNAL FUNCTIONS **
     */

    /**
     * @param _address: address of the receiver
     * @param _value: value of the transaction
     * @notice This function is called by the contract inside other functions in order to distribute the team and liquidity pool feel
     */
    function sendEth(address _address, uint256 _value) internal {
        (bool success, ) = _address.call{value: _value}("");
        if (!success) revert EthTransferFailed();
    }

    /**
     * @custom:section                           ** PRIVATE FUNCTIONS **
     */

    /**
     * @param value: is the amount of $ETH
     * @notice This function is used inside other function to get the current ETH / PANTHEON ratio
     */
    function _PANTHEONtoETH(uint256 value) private view returns (uint256) {
        return (value * totalEth) / totalSupply();
    }

    /**
     * @param value: is the amount of $PANTHEON
     * @notice This function is used inside other function to get the current PANTHEON / ETH ratio
     */
    function _ETHtoPANTHEON(uint256 value) private view returns (uint256) {
        return (value * totalSupply()) / (totalEth);
    }

    /**
     * @param _addr: Is the address used in the functions that call the _assemblyOwnerNotZero function
     * @notice This function is used inside other function to check that the address put as parameter is different from the zero address. It saves gas compared to a if statement + a revert with a custom error
     */
    function _assemblyOwnerNotZero(address _addr) private pure {
        assembly {
            if iszero(_addr) {
                mstore(0x00, "Zero address")
                revert(0x00, 0x20)
            }
        }
    }

    /**
     * @custom:section                           **  EXTERNAL VIEW / PURE FUNCTIONS **
     */

    /**
     * @param amount: is the amount of $ETH
     * @notice This function is used inside other function to get the current Mint price of $PANTHEON in $ETH
     */
    function getMintPantheon(uint256 amount) external view returns (uint256) {
        return
            (amount * (totalSupply()) * (_MINT_AND_REDEEM_FEE)) /
            (totalEth) /
            (_FEE_BASE_1000);
    }

    /**
     * @param amount: is the amount of $PANTHEON
     * @notice This function is used inside other function to get the current Redeem price of $PANTHEON in $ETH
     */
    function getRedeemPantheon(uint256 amount) external view returns (uint256) {
        return
            ((amount * totalEth) * (_MINT_AND_REDEEM_FEE)) /
            (totalSupply()) /
            (_FEE_BASE_1000);
    }

    /**
     * @notice This function is used inside other function to get the total amount of $ETH in the contract
     */
    function getTotalEth() external view returns (uint256) {
        return totalEth;
    }
}
