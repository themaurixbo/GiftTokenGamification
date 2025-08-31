// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * Aleph Hackathon -2025 - Hacker: Mauricio LARREA
 * GIFTOKEN GAMIFICATION — CampaignRegistry (OZ v5)
 * Catalog of campaigns that back each ERC-1155 `tokenId` with business rules:
 *  - issuer / merchant
 *  - unitValueUSD6 (e.g., $2.50 => 2_500_000)
 *  - time window (startTs / endTs)
 *  - maxSupply (soft cap metadata, actual supply tracked in GiftToken1155)
 *  - termsCidHash (IPFS/Filecoin)
 *  - active flag
 *
 * Access:
 *  - DEFAULT_ADMIN_ROLE: full control, can manage role admins
 *  - ISSUER_ROLE: allowed to create/toggle/update its own campaigns
 *
 * Notes:
 *  - OZ v5 imports
 *  - Keep tokenId unique per campaign
 */

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/access/AccessControl.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/Pausable.sol";

contract CampaignRegistry is AccessControl, Pausable {
    // Reuse the same role identifiers used across the system for clarity
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct Campaign {
        address issuer;         // company account (owner of the campaign)
        address merchant;       // default merchant (optional)
        uint256 tokenId;        // ERC-1155 id in GiftToken1155
        uint256 unitValueUSD6;  // price/value in USD with 6 decimals
        uint64  startTs;        // unix time (inclusive)
        uint64  endTs;          // unix time (exclusive); 0 => no end
        uint32  maxSupply;      // optional soft cap for minted vouchers
        bytes32 termsCidHash;   // IPFS/Filecoin CID hash for T&C
        bool    active;         // quick switch
    }

    mapping(uint256 => Campaign) private _campaigns;  // tokenId -> campaign
    mapping(uint256 => bool)     private _exists;     // tokenId -> exists

    event CampaignCreated(
        uint256 indexed tokenId,
        address indexed issuer,
        address merchant,
        uint256 unitValueUSD6
    );
    event CampaignUpdated(uint256 indexed tokenId, string field);
    event CampaignToggled(uint256 indexed tokenId, bool active);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _setRoleAdmin(ISSUER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    // -------- Admin / Control --------
    function pause()   external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // -------- CRUD --------

    /**
     * @notice Create a new campaign for a given tokenId.
     * @dev Fails if tokenId already exists.
     */
    function createCampaign(
        address issuer,
        address merchant,
        uint256 tokenId,
        uint256 unitValueUSD6,
        uint64  startTs,
        uint64  endTs,
        uint32  maxSupply,
        bytes32 termsCidHash,
        bool    active
    ) external whenNotPaused onlyRole(ISSUER_ROLE)
    {
        require(!_exists[tokenId], "CampaignRegistry: tokenId exists");
        require(issuer != address(0), "CampaignRegistry: issuer=0");
        require(unitValueUSD6 > 0, "CampaignRegistry: unitValue=0");
        if (endTs != 0) require(endTs > startTs, "CampaignRegistry: bad window");

        _campaigns[tokenId] = Campaign({
            issuer: issuer,
            merchant: merchant,
            tokenId: tokenId,
            unitValueUSD6: unitValueUSD6,
            startTs: startTs,
            endTs: endTs,
            maxSupply: maxSupply,
            termsCidHash: termsCidHash,
            active: active
        });
        _exists[tokenId] = true;

        emit CampaignCreated(tokenId, issuer, merchant, unitValueUSD6);
        emit CampaignToggled(tokenId, active);
    }

    /**
     * @notice Toggle active flag (on/off).
     */
    function toggleCampaign(uint256 tokenId, bool active_)
        external
        whenNotPaused
    {
        Campaign storage c = _mustExistAndOwned(tokenId);
        c.active = active_;
        emit CampaignToggled(tokenId, active_);
    }

    /**
     * @notice Update the unit value in USD (6 decimals).
     */
    function updateUnitValue(uint256 tokenId, uint256 newUSD6)
        external
        whenNotPaused
    {
        require(newUSD6 > 0, "CampaignRegistry: unitValue=0");
        Campaign storage c = _mustExistAndOwned(tokenId);
        c.unitValueUSD6 = newUSD6;
        emit CampaignUpdated(tokenId, "unitValueUSD6");
    }

    /**
     * @notice Update campaign time window.
     */
    function updateWindow(uint256 tokenId, uint64 startTs, uint64 endTs)
        external
        whenNotPaused
    {
        if (endTs != 0) require(endTs > startTs, "CampaignRegistry: bad window");
        Campaign storage c = _mustExistAndOwned(tokenId);
        c.startTs = startTs;
        c.endTs   = endTs;
        emit CampaignUpdated(tokenId, "window");
    }

    /**
     * @notice Update default merchant (optional).
     */
    function updateMerchant(uint256 tokenId, address merchant)
        external
        whenNotPaused
    {
        Campaign storage c = _mustExistAndOwned(tokenId);
        c.merchant = merchant;
        emit CampaignUpdated(tokenId, "merchant");
    }

    /**
     * @notice Update maxSupply (soft cap metadata).
     */
    function updateMaxSupply(uint256 tokenId, uint32 maxSupply)
        external
        whenNotPaused
    {
        Campaign storage c = _mustExistAndOwned(tokenId);
        c.maxSupply = maxSupply;
        emit CampaignUpdated(tokenId, "maxSupply");
    }

    /**
     * @notice Update terms CID hash (IPFS/Filecoin).
     */
    function updateTerms(uint256 tokenId, bytes32 termsCidHash)
        external
        whenNotPaused
    {
        Campaign storage c = _mustExistAndOwned(tokenId);
        c.termsCidHash = termsCidHash;
        emit CampaignUpdated(tokenId, "termsCidHash");
    }

    // -------- Views --------

    function getCampaign(uint256 tokenId)
        external
        view
        returns (Campaign memory)
    {
        require(_exists[tokenId], "CampaignRegistry: not found");
        return _campaigns[tokenId];
    }

    /**
     * @notice Returns whether the campaign is active AND within the time window.
     */
    function isActive(uint256 tokenId) external view returns (bool) {
        if (!_exists[tokenId]) return false;
        Campaign storage c = _campaigns[tokenId];
        if (!c.active) return false;
        if (c.startTs != 0 && block.timestamp < c.startTs) return false;
        if (c.endTs   != 0 && block.timestamp >= c.endTs) return false;
        return true;
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists[tokenId];
    }

    // -------- Internals --------

    /**
     * @dev Helper: require campaign exists and caller is allowed (admin or issuer).
     */
    function _mustExistAndOwned(uint256 tokenId)
        internal
        view
        returns (Campaign storage c)
    {
        require(_exists[tokenId], "CampaignRegistry: not found");
        c = _campaigns[tokenId];
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            require(hasRole(ISSUER_ROLE, msg.sender), "CampaignRegistry: not issuer/admin");
            require(msg.sender == c.issuer, "CampaignRegistry: issuer only");
        }
    }
}
