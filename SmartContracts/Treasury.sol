// SPDX-License-Identifier: MIT
/* Aleph Hackathon -2025 - Hacker: Mauricio LARREA*/
pragma solidity ^0.8.23;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/access/AccessControl.sol";

interface IERC20Dec6 { function decimals() external view returns (uint8); }

contract Treasury is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_FUNDS_ROLE = keccak256("ADMIN_FUNDS_ROLE");

    IERC20 public stable; // USDC/USDT (6 decimals)
    mapping(uint256 => uint256) public capUSD6; // per-campaign caps
    mapping(address => bool) public allowedRedeemers;

    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event CapSet(uint256 indexed tokenId, uint256 capUSD6);
    event RedeemerAuth(address indexed redeemer, bool allowed);
    event StableChanged(address oldStable, address newStable);

    constructor(address admin, address stable_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_FUNDS_ROLE, admin);
        stable = IERC20(stable_);
    }

    function setStable(address stable_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit StableChanged(address(stable), stable_);
        stable = IERC20(stable_);
    }

    function authorizeRedeemer(address redeemer, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedRedeemers[redeemer] = allowed;
        emit RedeemerAuth(redeemer, allowed);
    }

    function setCampaignCap(uint256 tokenId, uint256 cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        capUSD6[tokenId] = cap;
        emit CapSet(tokenId, cap);
    }

    function deposit(uint256 amount) external {
        stable.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(address to, uint256 amount) external onlyRole(ADMIN_FUNDS_ROLE) {
        stable.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }

    function pay(address to, uint256 amountUSD6, uint256 tokenId) external {
        require(allowedRedeemers[msg.sender], "not redeemer");
        if (capUSD6[tokenId] != 0) {
            require(amountUSD6 <= capUSD6[tokenId], "cap exceeded");
        }
        stable.safeTransfer(to, amountUSD6);
    }

    function balance() external view returns (uint256) {
        return IERC20(stable).balanceOf(address(this));
    }
}
