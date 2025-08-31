// SPDX-License-Identifier: MIT
/* Aleph Hackathon -2025 - Hacker: Mauricio LARREA*/

pragma solidity ^0.8.23;
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/access/AccessControl.sol";

contract MerchantRegistry is AccessControl {
    bytes32 public constant MERCHANT_ADMIN_ROLE = keccak256("MERCHANT_ADMIN_ROLE");

    struct Merchant {
        bool allowed;
        address payoutWallet;
        uint16 feeBps; // 0-10000
    }

    mapping(address => Merchant) public merchants;

    event MerchantAdded(address indexed merchant, address payoutWallet, uint16 feeBps);
    event MerchantRemoved(address indexed merchant);
    event MerchantUpdated(address indexed merchant, string field);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MERCHANT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function addMerchant(address merchant, address payoutWallet, uint16 feeBps)
        external onlyRole(MERCHANT_ADMIN_ROLE)
    {
        require(merchant != address(0) && payoutWallet != address(0), "zero");
        merchants[merchant] = Merchant(true, payoutWallet, feeBps);
        emit MerchantAdded(merchant, payoutWallet, feeBps);
    }

    function removeMerchant(address merchant) external onlyRole(MERCHANT_ADMIN_ROLE) {
        delete merchants[merchant];
        emit MerchantRemoved(merchant);
    }

    function setPayout(address merchant, address payoutWallet) external onlyRole(MERCHANT_ADMIN_ROLE) {
        merchants[merchant].payoutWallet = payoutWallet;
        emit MerchantUpdated(merchant, "payoutWallet");
    }

    function setFeeBps(address merchant, uint16 feeBps) external onlyRole(MERCHANT_ADMIN_ROLE) {
        merchants[merchant].feeBps = feeBps;
        emit MerchantUpdated(merchant, "feeBps");
    }

    function isAllowed(address merchant) external view returns (bool) {
        return merchants[merchant].allowed;
    }
}
