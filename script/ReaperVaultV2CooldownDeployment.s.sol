// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {ReaperVaultV2Cooldown} from "src/ReaperVaultV2Cooldown.sol";
import {ReaperZeroFeeController} from "src/ReaperZeroFeeController.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ADMIN, GUARDIAN, DEFAULT_ADMIN_ROLE, KEEPER, STRATEGIST} from "src/Roles.sol";

contract ReaperVaultV2CooldownDeployment is Script {
    using stdJson for string;

    function run() external {
        string memory configPath = "script/config/ReaperVaultV2Cooldown.input.json";
        string memory outputPath = _getEnvStringOr("OUTPUT", "script/output/ReaperVaultV2Cooldown.output.json");

        string memory json = vm.readFile(configPath);

        address token = stdJson.readAddress(json, ".token");
        string memory name = stdJson.readString(json, ".name");
        string memory symbol = stdJson.readString(json, ".symbol");
        uint256 tvlCap = stdJson.readUint(json, ".tvlCap");
        uint256 managementFeeCapBPS256 = stdJson.readUint(json, ".managementFeeCapBPS");
        require(managementFeeCapBPS256 <= type(uint16).max, "managementFeeCapBPS too large");
        uint16 managementFeeCapBPS = uint16(managementFeeCapBPS256);
        address treasury = stdJson.readAddress(json, ".treasury");
        address[] memory strategists = stdJson.readAddressArray(json, ".strategists");
        address[] memory multisigRoles = stdJson.readAddressArray(json, ".multisigRoles");
        require(multisigRoles.length == 3, "multisigRoles must have length 3");
        uint256 cooldownPeriod = stdJson.readUint(json, ".cooldownPeriod");

        address deployer = _maybeStartBroadcast();

        // Deploy and initialize FeeController
        ReaperZeroFeeController feeController = new ReaperZeroFeeController();

        // Deploy Vault, wiring the freshly deployed FeeController
        ReaperVaultV2Cooldown vault = new ReaperVaultV2Cooldown(
            token,
            name,
            symbol,
            tvlCap,
            managementFeeCapBPS,
            treasury,
            strategists,
            multisigRoles,
            address(feeController),
            cooldownPeriod
        );

        // revoke msg.sender from multisigRoles
        vault.revokeRole(ADMIN, deployer);
        vault.revokeRole(GUARDIAN, deployer);
        vault.revokeRole(KEEPER, deployer);
        vault.revokeRole(STRATEGIST, deployer);
        vault.revokeRole(DEFAULT_ADMIN_ROLE, deployer);

        vm.stopBroadcast();

        // assert deployer has no roles
        assert(!vault.hasRole(ADMIN, deployer));
        assert(!vault.hasRole(GUARDIAN, deployer));
        assert(!vault.hasRole(KEEPER, deployer));
        assert(!vault.hasRole(STRATEGIST, deployer));
        assert(!vault.hasRole(DEFAULT_ADMIN_ROLE, deployer));


        vm.createDir(_dirOf(outputPath), true);

        string memory objectKey = "deployment";
        string memory outJson = vm.serializeUint(objectKey, "chainId", block.chainid);
        outJson = vm.serializeUint(objectKey, "timestamp", block.timestamp);
        if (deployer != address(0)) {
            outJson = vm.serializeAddress(objectKey, "deployer", deployer);
        }
        outJson = vm.serializeAddress(objectKey, "deployer", deployer);
        outJson = vm.serializeAddress(objectKey, "reaperVaultV2Cooldown", address(vault));
        outJson = vm.serializeAddress(objectKey, "withdrawCooldownNft", address(vault.withdrawCooldownNft()));
        outJson = vm.serializeAddress(objectKey, "feeController", address(feeController));
        outJson = vm.serializeAddress(objectKey, "token", token);
        outJson = vm.serializeAddress(objectKey, "treasury", treasury);
        outJson = vm.serializeString(objectKey, "name", name);
        outJson = vm.serializeString(objectKey, "symbol", symbol);
        outJson = vm.serializeUint(objectKey, "tvlCap", tvlCap);
        outJson = vm.serializeUint(objectKey, "managementFeeCapBPS", managementFeeCapBPS);
        outJson = vm.serializeUint(objectKey, "cooldownPeriod", cooldownPeriod);
        outJson = vm.serializeAddress(objectKey, "multisigRoles-DEFAULT_ADMIN_ROLE", multisigRoles[0]);
        outJson = vm.serializeAddress(objectKey, "multisigRoles-ADMIN", multisigRoles[1]);
        outJson = vm.serializeAddress(objectKey, "multisigRoles-GUARDIAN", multisigRoles[2]);

        vm.writeJson(outJson, outputPath);
    }

    function _getEnvStringOr(string memory key, string memory defaultValue) internal view returns (string memory) {
        try vm.envString(key) returns (string memory v) {
            return v;
        } catch {
            return defaultValue;
        }
    }

    function _maybeStartBroadcast() internal returns (address deployer) {
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            deployer = vm.addr(pk);
            vm.startBroadcast(pk);
        } catch {
            vm.startBroadcast();
        }
    }

    function _dirOf(string memory path) internal pure returns (string memory) {
        bytes memory b = bytes(path);
        uint256 lastSlash = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == bytes1("/")) {
                lastSlash = i;
            }
        }
        if (lastSlash == 0) {
            return ".";
        }
        bytes memory dir = new bytes(lastSlash);
        for (uint256 i2 = 0; i2 < lastSlash; i2++) {
            dir[i2] = b[i2];
        }
        return string(dir);
    }
}


