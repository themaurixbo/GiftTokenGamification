// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 /* Aleph Hackathon -2025 - Hacker: Mauricio LARREA
 * PrivateUnwrap (fhEVM)
 * - Converts external encrypted amounts to handles (FHE.fromExternal)
 * - Grants transient access to the confidential token and consumes balance
 * - Requests public decryption via oracle and verifies KMS signatures in callback
 * - Emits RedemptionReady with plaintext for your Base Sepolia Redeemer
 */

import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.5/contracts/access/AccessControl.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.5/contracts/security/ReentrancyGuard.sol";

interface IConfToken {
  function consumeForUnwrap(address user, uint256 id, euint64 amount) external;
}

contract PrivateUnwrap is AccessControl, ReentrancyGuard {
  bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

  IConfToken public token;   // ConfidentialGiftToken1155 (fhEVM)
  address   public oracle;   // Decryption oracle (fhEVM)
  address   public issuer;   // Off-chain signer for EIP-712 voucher on Base

  struct Pending {
    address user;
    address merchant;
    uint256 id;
    uint256 nonce;
    uint256 expiry;
  }
  // requestId -> data
  mapping(uint256 => Pending) public pending;

  event RedemptionReady(
    uint256 requestId,
    address indexed user,
    address indexed merchant,
    uint256 indexed id,
    uint64 amountUSD6,
    uint256 nonce,
    uint256 expiry,
    uint256 srcChainId,
    address srcContract
  );

  constructor(address _token, address _oracle, address _issuer, address admin) {
    token  = IConfToken(_token);
    oracle = _oracle;
    issuer = _issuer;

    _grantRole(ADMIN_ROLE, admin);
    FHE.setDecryptionOracle(_oracle);
  }

  // ---------------- Admin ----------------

  function setIssuer(address newIssuer) external onlyRole(ADMIN_ROLE) { issuer = newIssuer; }

  function setOracle(address newOracle) external onlyRole(ADMIN_ROLE) {
    oracle = newOracle;
    FHE.setDecryptionOracle(newOracle);
  }

  // ---------------- Internal helper ----------------
  /// @dev Packs a single ciphertext handle into an array for FHE.requestDecryption
function _single(bytes32 ct) internal pure returns (bytes32[] memory arr) {
    arr = new bytes32[](1);
    arr[0] = ct;
}

  // ---------------- Unwrap flow ----------------
  function redeemEncrypted(
    uint256 id,
    externalEuint64 amountExt,
    bytes calldata attestation,
    address merchant,
    uint256 nonce,
    uint256 expiry
  ) external nonReentrant {
    // 1) external -> encrypted handle
    euint64 amt = FHE.fromExternal(amountExt, attestation);

    // 2) Allow token to use handle and consume encrypted balance
    FHE.allowTransient(amt, address(token));
    token.consumeForUnwrap(msg.sender, id, amt);

    // 3) Publicly decryptable + request decryption
    FHE.makePubliclyDecryptable(amt);

    uint256 reqId = FHE.requestDecryption(
      _single(FHE.toBytes32(amt)),
      this.onDecrypted.selector
    );

    pending[reqId] = Pending(msg.sender, merchant, id, nonce, expiry);
  }

  // Oracle callback with KMS signatures
  function onDecrypted(
    uint256 requestId,
    uint64 amountUSD6,
    bytes[] calldata signatures
  ) external {
    // Verify KMS signatures for this request
    FHE.checkSignatures(requestId, signatures);

    Pending memory p = pending[requestId];
    require(p.user != address(0), "req unknown");
    require(p.expiry == 0 || block.timestamp <= p.expiry, "expired");

    emit RedemptionReady(
      requestId,
      p.user,
      p.merchant,
      p.id,
      amountUSD6,
      p.nonce,
      p.expiry,
      block.chainid,
      address(this)
    );

    delete pending[requestId];
  }
}
