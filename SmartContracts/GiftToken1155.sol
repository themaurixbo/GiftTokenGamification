// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * Aleph Hackathon -2025 - Hacker: Mauricio LARREA
 * GIFTOKEN GAMIFICATION - GiftToken1155 (OZ v5.x)
 * Campaign-based voucher token (ERC-1155) with issuance and redemption roles.
 * - ISSUER:  RewardEngine (mints gift vouchers per campaign)
 * - REDEEMER: Redeemer contract (burns on redemption/payment) or user/approved operator
 * - PAUSER:  Operations wallet to pause in emergencies (blocks mint/transfer/burn via _update hook)
 *
 * NOTE: OpenZeppelin v5 
 */

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC1155/ERC1155.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/access/AccessControl.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/Pausable.sol";

contract GiftToken1155 is ERC1155, ERC1155Supply, AccessControl, Pausable {
    // ---- Roles ----
    bytes32 public constant ISSUER_ROLE   = keccak256("ISSUER_ROLE");   // allowed to mint
    bytes32 public constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE"); // allowed to burnFrom without user approval
    bytes32 public constant PAUSER_ROLE   = keccak256("PAUSER_ROLE");   // allowed to pause/unpause

    // ---- Optional ERC-20-like identification for frontends/marketplaces ----
    string public name;
    string public symbol;

    // ---- Per-token URIs (fallback to baseURI if empty) ----
    mapping(uint256 => string) private _tokenURIs;

    // ---- Domain events (in addition to standard ERC-1155 events) ----
    event GiftMinted(uint256 indexed id, address indexed to, uint256 amount);
    event GiftBurned(uint256 indexed id, address indexed from, uint256 amount);

    /**
     * @param baseURI_  ERC1155 base URI (e.g. ipfs://CID/{id}.json)
     * @param name_     Human-readable collection name (for UIs)
     * @param symbol_   Short ticker-like symbol (for UIs)
     * @param admin     Initial admin (gets DEFAULT_ADMIN_ROLE)
     */
    constructor(
        string memory baseURI_,
        string memory name_,
        string memory symbol_,
        address admin
    ) ERC1155(baseURI_) {
        name   = name_;
        symbol = symbol_;

        // Initial admins (you can add more later)
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Role hierarchy: all managed by DEFAULT_ADMIN_ROLE
        _setRoleAdmin(ISSUER_ROLE,   DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE,   DEFAULT_ADMIN_ROLE);
    }

    // -------- Admin / Configuration --------

    /**
     * @notice Update base URI (e.g., ipfs://CID/{id}.json)
     * @dev Only admin can change base URI
     */
    function setURI(string memory newuri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    /**
     * @notice Set a custom URI for a specific tokenId and emit the standard ERC-1155 `URI` event
     * @dev Frontends can pick this per-id URI first, otherwise they should resolve `uri(id)`
     */
    function setTokenURI(uint256 id, string calldata newuri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _tokenURIs[id] = newuri;
        emit URI(newuri, id); // standard ERC-1155 metadata event
    }

    /**
     * @dev Returns the effective metadata URI for `id`.
     * If a custom per-id URI is set, returns it; otherwise returns the base URI.
     */
    function uri(uint256 id) public view override returns (string memory) {
        string memory custom = _tokenURIs[id];
        return bytes(custom).length > 0 ? custom : super.uri(id);
    }

    /**
     * @notice Pause/unpause all transfers, mints and burns
     * @dev Enforced in the `_update` hook (OZ v5)
     */
    function pause()   external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // -------- Minting --------

    /**
     * @notice Mint gift vouchers for a given campaign (tokenId)
     * @param to      Receiver address
     * @param id      ERC-1155 token id (represents a campaign)
     * @param amount  Amount to mint
     * @param data    Arbitrary data (kept for ERC-1155 compatibility)
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data)
        external
        onlyRole(ISSUER_ROLE)
    {
        _mint(to, id, amount, data);
        emit GiftMinted(id, to, amount);
    }

    /**
     * @notice Batch mint (multiple ids/amounts)
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        onlyRole(ISSUER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
        // Standard ERC-1155 TransferBatch event is emitted by OZ
    }

    // -------- Burning --------

    /**
     * @notice Burn tokens from the caller or from an account for which the caller is approved
     * @dev Requires the caller to be the token owner or an operator approved via setApprovalForAll
     */
    function burn(address from, uint256 id, uint256 amount) public {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "GiftToken1155: not owner nor approved"
        );
        _burn(from, id, amount);
        emit GiftBurned(id, from, amount);
    }

    /**
     * @notice Burn tokens directly by the Redeemer contract (no prior user approval required)
     * @dev Assign REDEEMER_ROLE to your Redeemer contract to enable atomic redemption flows
     */
    function burnFrom(address from, uint256 id, uint256 amount)
        external
        onlyRole(REDEEMER_ROLE)
    {
        _burn(from, id, amount);
        emit GiftBurned(id, from, amount);
    }

    /**
     * @notice Batch burn (owner or approved operator)
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) public {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "GiftToken1155: not owner nor approved"
        );
        _burnBatch(from, ids, amounts);
    }

    // -------- Internals & Overrides (OZ v5: _update hook) --------

    /**
     * @dev In OZ v5 the `_update` hook replaces `_beforeTokenTransfer`.
     * We enforce the Pausable guard here to block mint/transfer/burn when paused.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override(ERC1155, ERC1155Supply)
    {
        require(!paused(), "GiftToken1155: paused");
        super._update(from, to, ids, values);
    }

    /**
     * @dev Supports ERC-1155 + AccessControl interfaces
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
