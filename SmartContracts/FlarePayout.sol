// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
 /* Aleph Hackathon -2025 - Hacker: Mauricio LARREA*/
 /* TRACK FLARE: We implement Flare Time Series Oracle (FTSO) */
 /* WE Settle in FLR using the FTSO rate.  We hold FLR for payouts.  
 The user submits an EIP-712–signed voucher referencing the redemption transaction on Base (or a ‘payout intent’).  
 We quote the FLR amount via FlarePriceProxy.getUSD6("FLR") and execute the payment.”*/

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/cryptography/EIP712.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/cryptography/ECDSA.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/access/Ownable.sol";

interface IFlarePriceProxy { function getUSD6(bytes32 symbol) external view returns (uint256); }

contract FlarePayout is EIP712, Ownable {
    using MessageHashUtils for bytes32;

    IFlarePriceProxy public price;
    address public signer;

    event Claimed(address indexed user, uint256 usd6, uint256 flrPaid, bytes32 baseRef);

    constructor(address price_, address signer_)
        EIP712("GIFTOKEN-FLR", "1")
        Ownable(msg.sender)  // <-- Fix: Pass initialOwner to Ownable
    {
        price = IFlarePriceProxy(price_);
        signer = signer_;
    }

    function setSigner(address s) external onlyOwner { signer = s; }

    struct Claim { address user; uint256 usd6; bytes32 baseRef; uint256 deadline; }
    bytes32 constant CLAIM_TYPEHASH = keccak256("Claim(address user,uint256 usd6,bytes32 baseRef,uint256 deadline)");

    function claim(Claim calldata c, bytes calldata sig) external {
        require(block.timestamp <= c.deadline, "expired");
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            CLAIM_TYPEHASH, c.user, c.usd6, c.baseRef, c.deadline
        )));
        address rec = ECDSA.recover(digest, sig);
        require(rec == signer, "bad sig");

        uint256 flrUsd6 = price.getUSD6(keccak256("FLR"));
        require(flrUsd6 > 0, "no price");
        uint256 amountFLR = (c.usd6 * 1e18) / flrUsd6;

        (bool ok, ) = payable(c.user).call{value: amountFLR}("");
        require(ok, "pay fail");

        emit Claimed(c.user, c.usd6, amountFLR, c.baseRef);
    }

    receive() external payable {}
}