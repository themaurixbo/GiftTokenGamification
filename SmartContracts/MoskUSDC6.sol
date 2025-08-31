// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
 /* Aleph Hackathon -2025 - Hacker: Mauricio LARREA*/
/**
 * MockUSDC (6 decimals) for testnets without official Circle USDC.
 * - Mintable by DEFAULT_ADMIN_ROLE
 * - Optional faucetMint for quick demos (limit per address)
 */
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC20/ERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/access/AccessControl.sol";

contract MockUSDC6 is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant FAUCET_LIMIT = 1000 * 1e6; // 1,000 USDC (6 dec)
    mapping(address => uint256) public faucetMinted;

    constructor(address admin) ERC20("Mock USDC", "mUSDC") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    function decimals() public pure override returns (uint8) { return 6; }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice Dev faucet: each address can mint up to FAUCET_LIMIT total
    function faucetMint(uint256 amount) external {
        require(amount > 0, "amount=0");
        uint256 newTotal = faucetMinted[msg.sender] + amount;
        require(newTotal <= FAUCET_LIMIT, "faucet cap");
        faucetMinted[msg.sender] = newTotal;
        _mint(msg.sender, amount);
    }
}
