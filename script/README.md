## ReaperVaultV2Cooldown – Deployment Guide

### Overview

This directory contains a Foundry script to deploy `ReaperVaultV2Cooldown` using a JSON configuration file and to write deployment artifacts to a JSON output file.

- **Script**: `script/ReaperVaultV2CooldownDeployment.s.sol`
- **Default config**: `script/config/ReaperVaultV2Cooldown.input.json`
- **Default output**: `script/output/ReaperVaultV2Cooldown.output.json`

By default, the script reads the config at `script/config/ReaperVaultV2Cooldown.input.json`. You can override only the output path via env `OUTPUT`.

### Configuration file (input)

Edit `script/config/ReaperVaultV2Cooldown.input.json` with real parameters:

```json
{
  "token": "0x...",                      // underlying ERC20
  "name": "Reaper Vault Cooldown",       // vault ERC20 name
  "symbol": "rf-COOL",                  // vault ERC20 symbol
  "tvlCap": 0,                            // uint, max TVL (0 or max means uncapped when updated)
  "managementFeeCapBPS": 500,             // uint <= 10000
  "treasury": "0x...",                   // fee receiver
  "strategists": ["0x...", "0x..."],    // array of addresses
  "multisigRoles": [                       // EXACTLY 3 addresses in order
    "0x...",                               // DEFAULT_ADMIN_ROLE
    "0x...",                               // ADMIN
    "0x..."                                // GUARDIAN
  ],
  "cooldownPeriod": 0                      // seconds
}
```

Constraints enforced by the script/contract:
- **multisigRoles.length must be 3** (order matters as above).
- **managementFeeCapBPS <= 10000** and fits in uint16.

### Environment variables

- **RPC_URL**: JSON-RPC endpoint.
- **PRIVATE_KEY**: hex private key of deployer (no 0x prefix required by Foundry; both are accepted by env reader here). If not set, you must pass signing details to `forge script` via flags, and the script will call `vm.startBroadcast()` without an inline key.

### Commands

1) Dry run (no broadcast):

```bash
forge script script/ReaperVaultV2CooldownDeployment.s.sol:ReaperVaultV2CooldownDeployment --rpc-url $RPC_URL
```

2) Broadcast using env PRIVATE_KEY (recommended):

```bash
export PRIVATE_KEY=0xabc...                  # or without 0x
forge script script/ReaperVaultV2CooldownDeployment.s.sol:ReaperVaultV2CooldownDeployment --rpc-url $RPC_URL --broadcast
```

3) With verification (requires ETHERSCAN_API_KEY and a supported chain):

```bash
forge script script/ReaperVaultV2CooldownDeployment.s.sol:ReaperVaultV2CooldownDeployment --rpc-url $RPC_URL --broadcast --verify --slow
```


### Output (artifacts)

After a successful broadcast, the script writes a JSON artifact (default `script/output/ReaperVaultV2Cooldown.output.json`) with fields like:

- **chainId**, **timestamp**, **deployer**
- **reaperVaultV2Cooldown** (vault address)
- **withdrawCooldownNft** (cooldown NFT address created by the vault)
- **feeController** (freshly deployed and initialized)
- **token**, **treasury**
- **name**, **symbol**, **tvlCap**, **managementFeeCapBPS**, **cooldownPeriod**

