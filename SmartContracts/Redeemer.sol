// SPDX-License-Identifier: MIT
/* Aleph Hackathon -2025 - Hacker: Mauricio LARREA*/
pragma solidity ^0.8.23;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC1155/IERC1155.sol";

interface ICampaignRegistry {
    function isActive(uint256 tokenId) external view returns (bool);
    function getCampaign(uint256 tokenId) external view returns (
        address issuer, address merchant, uint256 tokenIdOut, uint256 unitValueUSD6,
        uint64 startTs, uint64 endTs, uint32 maxSupply, bytes32 termsCidHash, bool active
    );
}

interface ITreasury {
    function pay(address to, uint256 amountUSD6, uint256 tokenId) external;
}

interface IMerchantRegistry {
    function merchants(address m) external view returns (bool allowed, address payoutWallet, uint16 feeBps);
}

interface IGift1155 {
    function burnFrom(address from, uint256 id, uint256 amount) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

contract Redeemer is AccessControl, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IGift1155 public gift;
    ICampaignRegistry public reg;
    IMerchantRegistry public merchants;
    ITreasury public treasury;

    bool public paused;

    event Redeemed(address indexed user, address indexed merchant, uint256 indexed tokenId, uint256 amount, uint256 usd6Paid);

    constructor(address admin, address gift_, address reg_, address merchants_, address treasury_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        gift = IGift1155(gift_);
        reg = ICampaignRegistry(reg_);
        merchants = IMerchantRegistry(merchants_);
        treasury = ITreasury(treasury_);
    }

    function setPaused(bool p) external onlyRole(PAUSER_ROLE) { paused = p; }

    function quoteRedeem(uint256 tokenId, uint256 amount) public view returns (uint256 usd6) {
        (, , , uint256 unitValueUSD6, , , , , ) = reg.getCampaign(tokenId);
        usd6 = unitValueUSD6 * amount; // 6-decimals math (no FX here)
    }

    function redeem(uint256 tokenId, uint256 amount, address merchant)
        external nonReentrant
    {
        require(!paused, "paused");
        require(reg.isActive(tokenId), "inactive campaign");
        (bool allowed, address payout, uint16 feeBps) = merchants.merchants(merchant);
        require(allowed && payout != address(0), "merchant not allowed");

        // burn user's vouchers (REDEEMER_ROLE must be granted to this contract in GiftToken)
        gift.burnFrom(msg.sender, tokenId, amount);

        uint256 gross = quoteRedeem(tokenId, amount);
        uint256 fee = (gross * feeBps) / 10_000;
        uint256 net = gross - fee;

        // pay merchant in USDC from Treasury
        treasury.pay(payout, net, tokenId);

        emit Redeemed(msg.sender, merchant, tokenId, amount, net);
    }
}
