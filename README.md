
# GIFTOKEN GAMIFICATION  
_Rewards & payments with on-chain vouchers (ERC-1155) redeemable for USDC — dual deploy (Base/Lisk), optional payout in FLR (Flare FTSO) and confidential distributions (Zama fhEVM)._
ALEPH HACKATHON 2025

## 1) One-liner
Interoperable performance rewards funded in USDC and tokenized as **GIF Tokens** (ERC-1155 vouchers), redeemable as payment across our **GIFTOKEN Smart Market**. Optional **payout in FLR** at FTSO price and **confidential distributions** with Zama fhEVM.

## 2) Problem → Solution
- **Problem:** loyalty points are siloed, devalue quickly, and redemptions are frictioned; sales incentives leak or require manual ops; sensitive distributions (airdrops/grants) expose amounts on-chain.  
- **Solution:** 1) companies deposit **USDC**, 2) define deterministic KPIs, 3) when met, we mint **GIF** vouchers (ERC-1155), 4) users redeem at merchants (GIF burns, **USDC** paid from **Treasury**), 5) optional **FLR payout** using **Flare FTSO** prices, 6) optional **confidential distributions** on **Zama** with wrap/unwrap.

---

## 3) Why this matters 
- Higher **activation & retention** (deterministic value; not points breakage).  
- Lower **CAC** via referrals/tasks; measurable ROI per campaign.  
- **Stable value** (USDC) in inflationary markets.  
- **Merchant acceptance** with automated USDC settlement.  
- **Privacy** for strategic allocations (Zama confidential).

---

## 4) Tracks & Bounties — How we qualify

| Track | What we use | What judges will see in demo |
|---|---|---|
| **Base / Lisk (Founder Track)** | Full DeFi & Payments flow: ERC-1155 vouchers, Campaign & Merchant registries, Treasury USDC, Redeemer (burn→pay). Dual deploy (Base Sepolia + Lisk Sepolia). | Mint GIF, redeem at merchant, USDC/mUSDC settlement, fees & caps. Low gas, clean role model, verified contracts. |
| **Flare (FTSO)** | `FlarePriceProxy` on **Coston2** stores **FLR/USD** (USD6) pushed from FTSO/FDC (manual or bot). `FlarePayout` lets user **claim FLR** based on USD amount, at FTSO price. | “Get paid in FLR” button: show price read, claim in FLR, TX on explorer. This is onboarding to Flare via rewards. |
| **Zama (Confidential)** | `ConfidentialGiftToken` (fhEVM skeleton) with encrypted balances & `UnwrapRequested`. Relayer mints/pays on Base upon unwrap. | Show confidential mint, then unwrap intent and corresponding Base settlement. Protects airdrops/vesting. |

---

## 5) Architecture (high level)

```
               +--------------------+        +--------------------+
Sales KPIs --> | CampaignRegistry   |        | MerchantRegistry   | <-- Onboarded merchants
               +---------+----------+        +----------+---------+
                         |                              |
                         v                              v
+------------+   mint  +--------------------+   burn  +--------------------+   pay USDC
|  Issuer    | ------> | GiftToken1155 (1155)| -----> | Redeemer            | ----------->
+------------+         +--------------------+         +----------+---------+             | 
                                                 calls         |                        v
                                                           +---+---+            +----------------+
                                                           |Treasury|----USDC-->| Merchant Wallet|
                                                           +------- +           +----------------+

Optional Flare payout (Coston2):
User -> FlarePayout.claim(Claim, sig) --reads--> FlarePriceProxy (FTSO price) --pays FLR-->

Optional Zama fhEVM:
Issuer -> ConfidentialGiftToken (encrypted) -> user requestUnwrap -> relayer -> Base mint/pay
```

---

## 6) Contracts (what each one does)

| Contract | Network | Purpose | Key funcs / roles |
|---|---|---|---|
| `GiftToken1155` | Base, Lisk | ERC-1155 vouchers per campaign; mint by issuer, burn on redeem. | `mint/mintBatch`, `burn/burnFrom`, `setURI`. Roles: `ISSUER_ROLE`, `REDEEMER_ROLE`, `PAUSER_ROLE`. |
| `CampaignRegistry` | Base, Lisk | Business rules for each `tokenId`: unit value USD(6), window, issuer, caps, terms. | `createCampaign`, `isActive`, `update*`. Role: `ISSUER_ROLE`. |
| `MerchantRegistry` | Base, Lisk | Allowlist + payout wallet + fee bps. | `addMerchant`, `setPayout`, `setFeeBps`. Role: `MERCHANT_ADMIN_ROLE`. |
| `Treasury` | Base, Lisk | Holds USDC/mUSDC; pays merchants; optional per-campaign cap. | `deposit`, `pay(to, usd6, tokenId)`, `authorizeRedeemer`, `setStable`, `balance`. |
| `Redeemer` | Base, Lisk | Atomic burn→pay flow; reads rules, applies fee, settles from Treasury. | `quoteRedeem`, `redeem`. Role: `PAUSER_ROLE`. |
| `MockUSDC6` | Lisk | 6-decimals mock stablecoin for Lisk testnet. | `decimals=6`, `mint`, `faucetMint`. |
| `FlarePriceProxy(Simple)` | Flare Coston2 | On-chain FLR/USD6 board (from FTSO/FDC via updater). | `pushPrice("FLR", usd6, ts)`, `getUSD6("FLR")`. Role: `UPDATER_ROLE`. |
| `FlarePayout` | Flare Coston2 | Claim in FLR with EIP-712 voucher; price via `FlarePriceProxy`. | `claim(Claim, sig)`, `setSigner`, `receive()`. |
| `ConfidentialGiftToken` (skeleton) | Zama fhEVM | Encrypted balances / vesting; unwrap intent to public layer. | `requestUnwrap(amount, ref)`, events. |

---

## 7) Deployments

 https://9000-firebase-studio-1756499632712.cluster-hf4yr35cmnbd4vhbxvfvc6cp5q.cloudworkstations.dev
 

### Base Sepolia
- `GiftToken1155`: `<(https://sepolia.basescan.org/address/0xeaE8e75D49d4b808D00332F03c8E71A315Df9F28#code)>` (Verified)  
- `CampaignRegistry`: `(https://sepolia.basescan.org/address/0xEbd6E9067A9EF28458Fbc9C5Ff8008dE92A10bcD#code)`  (Verified) 
- `MerchantRegistry`: `(https://sepolia.basescan.org/address/0x0861b535d353f37b1DEbB380e32FF2737688F583#code)`  (Verified) 
- `Treasury (USDC: 0x036CbD53842c5426634e7929541eC2318f3dCF7e)`: `(https://sepolia.basescan.org/address/0x9Aad35f76a74a4638F78256D4E13B500Bb736313#code)` (Verified)  
- `Redeemer`: `(https://sepolia.basescan.org/address/0x0C91d373F3D47fF46b5e0B993fDf247039646Eaf#code)`(Verified) 

### Lisk Sepolia
- `MockUSDC6`: `<(https://sepolia.etherscan.io/address/0xb5F9f77510C0416892a9526F32B33B5B813F347C#code)>`  
- `GiftToken1155`: `<addr>`  
- `CampaignRegistry`: `<addr>`  
- `MerchantRegistry`: `<addr>`  
- `Treasury (mUSDC)`: `<addr>`  
- `Redeemer`: `<addr>`

### Flare Coston2
- `FlarePriceProxySimple`: `(https://testnet.routescan.io/address/0xeaE8e75D49d4b808D00332F03c8E71A315Df9F28/contract/114/code)` (Verified)  
- `FlarePayout (price=<proxy>, signer=<signer_addr>)`: `(https://testnet.routescan.io/address/0xEbd6E9067A9EF28458Fbc9C5Ff8008dE92A10bcD/contract/114/code)` (Verified)

### Zama fhEVM (optional demo)
- `ConfidentialGiftToken`: `<(https://sepolia.etherscan.io/address/0x6B6C65d110441Aaaa7e7F5E45c15AdaB93B2c586#code)>`(Verified)
- `PrivateUnwrap.sol`: https://sepolia.etherscan.io/address/0x4DB1Ff8c868Cd798a175035388358aC83A5c6490#code (Verified)

---

## 8) How to run the demo (7-minute script)

1) **Setup (once):**  
   - Add networks: Base Sepolia (84532), Lisk Sepolia (4202), Flare Coston2 (114).  
   - Get test funds: Base (ETH+USDC), Lisk (ETH + faucet mUSDC), Flare (C2FLR).  
   - Grant roles:  
     - `GiftToken1155`: `ISSUER_ROLE` → your wallet; `REDEEMER_ROLE` → `Redeemer`.  
     - `Treasury`: `authorizeRedeemer(Redeemer, true)`.  
     - `MerchantRegistry`: add merchant (payout wallet + `feeBps`).  

2) **Create a campaign** (Base):  
   - `CampaignRegistry.createCampaign(issuer=you, merchant=0x0, tokenId=1, unitValueUSD6=5_000_000, start=0, end=0, maxSupply=100000, terms=0x0, active=true)`.

3) **Fund Treasury** (Base):  
   - Approve & `deposit(50_000_000)` = 50 USDC.

4) **Mint vouchers**:  
   - `GiftToken1155.mint(user, id=1, amount=10, data="0x")`.

5) **Redeem at merchant**:  
   - `Redeemer.quoteRedeem(1, 2)` → expect `10_000_000`.  
   - `Redeemer.redeem(1,2,<merchant>)` → event `Redeemed(...)` and USDC → merchant.

6) **Switch to Lisk (dual)**:  
   - `MockUSDC6.faucetMint(100_000_000)` (100 mUSDC) and deposit to Lisk `Treasury`.  
   - Repeat a quick redeem to show parity and low fees (Founder Track).

7) **Flare payout** (optional):  
   - On **Coston2**, call `FlarePriceProxySimple.pushPrice("FLR", 25000, now)` (0.025 USD).  
   - Fund `FlarePayout` with some C2FLR.  
   - Use our simple signer (or the same wallet) to sign a **Claim** and call `FlarePayout.claim(...)` → wallet receives FLR at FTSO price.

8) **Zama (optional)**:  
   - Show `requestUnwrap(amountUSD6, ref)` event; explain the relayer mints/pays on Base referencing `ref` (confidential distribution → public settlement).

---

## 9) How to use / reproduce (Remix)

- **Compiler:** Solidity `0.8.23/0.8.24`, optimizer **ON (200 runs)**.  
- **Deploy order (Base & Lisk):** `GiftToken1155` → `CampaignRegistry` → `MerchantRegistry` → `Treasury` → `Redeemer`.  
- **Verification:**  
  - Base: Remix plugin “Contract Verification – Etherscan” (BaseScan) or upload Standard-JSON.  
  - Flare: Sourcify plugin o verificación en Blockscout (Coston2).  
- **USDC addresses:** Base Sepolia USDC (Circle): `0x036CbD53842c5426634e7929541eC2318f3dCF7e`. Lisk: use `MockUSDC6`.

---

## 10) Roles & Permissions (quick)

- **GiftToken1155**  
  - `DEFAULT_ADMIN_ROLE`: add/remove roles.  
  - `ISSUER_ROLE`: can `mint`.  
  - `REDEEMER_ROLE`: can `burnFrom` (used by `Redeemer`).  
  - `PAUSER_ROLE`: pause hook.

- **CampaignRegistry**: `ISSUER_ROLE` manages its campaigns.  
- **MerchantRegistry**: `MERCHANT_ADMIN_ROLE` manages merchants.  
- **Treasury**: `authorizeRedeemer(addr, true)` authorizes payouts; `ADMIN_FUNDS_ROLE` withdraw.  
- **FlarePriceProxy**: `UPDATER_ROLE` pushes price.  
- **FlarePayout**: owner sets `signer`.

---

## 11) Front-end network switch (snippet)

```js
async function switchNetwork(chainId, name, rpc, symbol, explorer) {
  try {
    await window.ethereum.request({ method:'wallet_switchEthereumChain', params:[{ chainId }] });
  } catch (e) {
    if (e.code === 4902) {
      await window.ethereum.request({
        method:'wallet_addEthereumChain',
        params:[{ chainId, chainName:name, rpcUrls:[rpc],
          nativeCurrency:{ name:symbol, symbol, decimals:18 }, blockExplorerUrls:[explorer] }]
      });
    } else throw e;
  }
}
// Base Sepolia
await switchNetwork('0x14A34','Base Sepolia','https://sepolia.base.org','ETH','https://sepolia.basescan.org');
// Lisk Sepolia
await switchNetwork('0x106A','Lisk Sepolia','https://rpc.sepolia-api.lisk.com','ETH','https://sepolia-blockscout.lisk.com');
// Flare Coston2
await switchNetwork('0x72','Flare Coston2','https://coston2-api.flare.network/ext/C/rpc','C2FLR','https://coston2-explorer.flare.network');
```

---

## 12) Optional services (for production / stronger scoring)

### A) Flare **FTSO updater bot**
Reads FTSO/FDC and pushes `pushPrice("FLR", usd6, ts)` to `FlarePriceProxy`. (En demo puedes hacerlo manual desde Remix).  
`.env` template:
```
FLARE_RPC_URL=...
UPDATER_PK=0x...
PRICE_PROXY_ADDR=0x...
# If reading FTSO directly, add the reader contract/envs here
```

### B) **Signer** (EIP-712) for FlarePayout
After a Base `Redeemed` tx, it verifies logs and signs a `Claim`. (En demo puedes firmar local con la misma wallet).

`.env` template:
```
BASE_RPC_URL=https://sepolia.base.org
REDEEMER_ADDR=0x<base_redeemer>
FLARE_PAYOUT_ADDR=0x<flare_payout>
FLARE_CHAIN_ID=114
SIGNER_PK=0x<private_key_for_signer_>
```

---

## 13) Security & Compliance notes
- Minimal approvals: `Redeemer` has `REDEEMER_ROLE` only on `GiftToken1155`.  
- Treasury never holds volatile assets; only USDC/mUSDC.  
- Campaign windows & caps reduce abuse.  
- Payout fees are explicit; event logs enable audits.  
- Confidential allocations (Zama) keep amounts off-chain until unwrap.

---

## 14) Roadmap (post-hackathon)
- Chainlink/Flare hybrid price sources & heartbeat thresholds.  
- Multi-merchant split & partial redemptions.  
- zk-proofs for KPI validation inputs.  
- Full fhEVM implementation with encrypted arithmetic & audited relayer.

---

## 15) Troubleshooting (quick)
- **Remix shows “pending…”** → speed up or cancel in MetaMask; switch RPC; re-deploy.  
- **Verification fails** → check compiler version & optimizer runs; constructor args order.  
- **No balances in Treasury** → approve USDC then `deposit()`.  
- **Flare claim reverts** → ensure `FlarePayout` has C2FLR; `priceProxy` has a recent price; signature domain matches.

---

## 16) License
MIT

---

### Contact
Team: **GIFTOKEN GAMIFICATION**  
Email: `mauricio.larrea.s@gmail.com` · X/Telegram: `<@The_Maurix>`
