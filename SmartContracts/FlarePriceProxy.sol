// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
 /* Aleph Hackathon -2025 - Hacker: Mauricio LARREA*/
 /* TRACK FLARE: We implement Flare Time Series Oracle (FTSO) */
 /* An updater service reads price feeds from Flare’s Time Series Oracle (FTSO) and writes them to our smart contract*/
 /* Users can redeem and get paid in FLR at the prevailing FTSO rate when they claim.
    NOTES  FLARE: We store on-chain the FLR/USD6 price (and any other pairs we whitelist) and expose getUSD6(symbol).
   Our UPDATER_ROLE bot reads Flare’s FTSO and pushes updates on-chain every epoch. 
   Our dApp uses this to quote payouts in FLR, and the FlarePayout contract consumes it at claim time.
   FOR THIS DEMO: We integrate with FTSO—our price feed comes from Flare. 
                  A bot publishes it in production; for the demo, we input it manually for simplicity.
 */

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/access/AccessControl.sol";

contract FlarePriceProxySimple is AccessControl {
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    struct Feed { uint256 usd6; uint64 ts; bool exists; }
    mapping(string => Feed) public feeds; // "FLR", "BTC", etc.

    event PricePushed(string symbol, uint256 usd6, uint64 ts);

    constructor(address admin, address updater) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPDATER_ROLE, updater);
    }

    function pushPrice(string calldata symbol, uint256 usd6, uint64 ts)
        external onlyRole(UPDATER_ROLE)
    {
        require(usd6 > 0, "price=0");
        feeds[symbol] = Feed(usd6, ts, true);
        emit PricePushed(symbol, usd6, ts);
    }

    function getUSD6(string calldata symbol) external view returns (uint256) {
        require(feeds[symbol].exists, "no feed");
        return feeds[symbol].usd6;
    }
}