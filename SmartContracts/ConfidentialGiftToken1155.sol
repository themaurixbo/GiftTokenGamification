// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * Aleph Hackathon -2025 - Hacker: Mauricio LARREA
 * GIFTOKEN GAMIFICATION — ConfidentialGiftToken1155 (fhEVM)
 *
 * Purpose
 * -------
 * This contract holds confidential balances per (owner, tokenId) using Zama fhEVM.
 * It is NOT a standard ERC-1155; it acts as the "confidential twin" for campaign balances.
 *
 * Key Points
 * ----------
 * - Uses Zama's FHE library types (euint64) and operators for encrypted math on-chain.
 * - Uses the 'select' pattern to avoid branching on encrypted booleans.
 * - Access control over ciphertext handles via FHE.allow / FHE.allowTransient.
 * - No FHE operations in view/pure functions.
 *
 * Roles
 * -----
 * - ISSUER_ROLE: can mint encrypted balances (e.g., your RewardEngine)
 * - UNWRAP_ROLE: PrivateUnwrap contract consumes encrypted balances for unwrapping
 * - PAUSER_ROLE: ops can pause/unpause
 *
 * Amounts & Types
 * ---------------
 * - Amounts are in USD6 (6 decimals notion) represented as euint64.
 * - Avoid arithmetic with euint256/eaddress per library constraints.
 */

import {FHE, euint64, ebool, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";

// OpenZeppelin (v4.9.5 for Remix compatibility)
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.5/contracts/access/AccessControl.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.5/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.5/contracts/security/Pausable.sol";

interface IConfidentialGiftToken1155 {
  function consumeForUnwrap(address user, uint256 id, euint64 amount) external;
  function getEncryptedBalance(address user, uint256 id) external view returns (bytes32);
}

contract ConfidentialGiftToken1155 is AccessControl, Pausable, ReentrancyGuard, IConfidentialGiftToken1155 {
  // --- Roles ---
  bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
  bytes32 public constant UNWRAP_ROLE = keccak256("UNWRAP_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  // Whether a tokenId (campaign) is confidential in this fhEVM contract
  mapping(uint256 => bool) public isConfidential;

  // Encrypted balances: (owner, tokenId) -> euint64 handle
  mapping(address => mapping(uint256 => euint64)) private encBalance;

  // Events for off-chain UX and observability
  event EncryptedMint(address indexed to, uint256 indexed id, bytes32 newBalanceHandle);
  event EncryptedTransfer(address indexed from, address indexed to, uint256 indexed id, bytes32 fromBalHandle, bytes32 toBalHandle);
  event EncryptedConsumedForUnwrap(address indexed user, uint256 indexed id, bytes32 newBalanceHandle);
  event ConfidentialFlagSet(uint256 indexed id, bool enabled);

  constructor(address admin) {
    // Mirror your public ERC-1155 pattern: admin + deployer as default admins
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    _grantRole(PAUSER_ROLE, admin);
  }

  // ---------------- Admin ----------------

  /// @notice Toggle confidential mode for a campaign tokenId
  function setConfidential(uint256 id, bool v) external onlyRole(DEFAULT_ADMIN_ROLE) {
    isConfidential[id] = v;
    emit ConfidentialFlagSet(id, v);
  }

  /// @notice Pause all state-changing functions guarded by whenNotPaused
  function pause() external onlyRole(PAUSER_ROLE) { _pause(); }

  /// @notice Unpause
  function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

  // ---------------- Mint (confidential) ----------------

  /**
   * @notice Mint encrypted balance for `to` on token `id`
   * @dev `amountExt` must come from the Relayer SDK (externalEuint64 + attestation)
   * @param to        recipient address
   * @param id        campaign tokenId
   * @param amountExt encrypted amount (externalEuint64)
   * @param att       attestation signatures from coprocessors (Gateway)
   */
  function mintConfidential(
    address to,
    uint256 id,
    externalEuint64 amountExt,
    bytes calldata att
  ) external nonReentrant whenNotPaused onlyRole(ISSUER_ROLE) {
    require(isConfidential[id], "not confidential");

    // Convert external encrypted input → internal encrypted handle (attestation verified)
    euint64 amt = FHE.fromExternal(amountExt, att);

    // encBalance[to][id] += amt (all encrypted)
    encBalance[to][id] = FHE.add(encBalance[to][id], amt);

    // ACL: let the user and this contract keep using the handle in future txs
    FHE.allow(encBalance[to][id], to);
    FHE.allow(encBalance[to][id], address(this));

    emit EncryptedMint(to, id, FHE.toBytes32(encBalance[to][id]));
  }

  // ---------------- Transfer (confidential) ----------------

  /**
   * @notice Transfer encrypted amount between users for a given tokenId
   * @dev Uses `select` to avoid branching on encrypted booleans.
   */
  function transferConfidential(
    address to,
    uint256 id,
    externalEuint64 amountExt,
    bytes calldata att
  ) external nonReentrant whenNotPaused {
    require(isConfidential[id], "not confidential");

    // 1) Convert external encrypted input
    euint64 amt = FHE.fromExternal(amountExt, att);

    // 2) The caller must be allowed to pass this encrypted handle
    require(FHE.isSenderAllowed(amt), "no access");

    // 3) ok = (amt <= encBalance[from][id])  — use FHE.le (<=)
    ebool ok = FHE.le(amt, encBalance[msg.sender][id]);
    euint64 txAmt = FHE.select(ok, amt, FHE.asEuint64(0));

    // 4) Update encrypted balances
    encBalance[msg.sender][id] = FHE.sub(encBalance[msg.sender][id], txAmt);
    encBalance[to][id]         = FHE.add(encBalance[to][id],         txAmt);

    // 5) Refresh ACLs for future ops
    FHE.allow(encBalance[msg.sender][id], msg.sender);
    FHE.allow(encBalance[to][id],         to);
    FHE.allow(encBalance[msg.sender][id], address(this));
    FHE.allow(encBalance[to][id],         address(this));

    emit EncryptedTransfer(
      msg.sender, to, id,
      FHE.toBytes32(encBalance[msg.sender][id]),
      FHE.toBytes32(encBalance[to][id])
    );
  }

  // ---------------- Consume for Unwrap (called by PrivateUnwrap) ----------------

  /**
   * @notice Burns/consumes an encrypted amount from `user` balance (for unwrap flows)
   * @dev Caller must have UNWRAP_ROLE. Caller must first grant us transient access to `amount`.
   */
  function consumeForUnwrap(
    address user,
    uint256 id,
    euint64 amount
  ) external nonReentrant whenNotPaused onlyRole(UNWRAP_ROLE) {
    // Ensure this contract (callee) is allowed to use the handle `amount` (passed by PrivateUnwrap)
    require(FHE.isSenderAllowed(amount), "no access/handle");

    // ok = (amount <= encBalance[user][id]) — use FHE.le (<=)
    ebool ok = FHE.le(amount, encBalance[user][id]);
    euint64 burnAmt = FHE.select(ok, amount, FHE.asEuint64(0));

    encBalance[user][id] = FHE.sub(encBalance[user][id], burnAmt);

    // Keep handles usable by user and this contract
    FHE.allow(encBalance[user][id], user);
    FHE.allow(encBalance[user][id], address(this));

    emit EncryptedConsumedForUnwrap(user, id, FHE.toBytes32(encBalance[user][id]));
  }

  // ---------------- Read helper (handle only) ----------------

  /**
   * @notice Returns the bytes32 handle of the encrypted balance (no FHE ops in view)
   */
  function getEncryptedBalance(address user, uint256 id) external view returns (bytes32) {
    return FHE.toBytes32(encBalance[user][id]);
  }
}
