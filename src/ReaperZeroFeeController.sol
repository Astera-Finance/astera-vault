// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFeeController} from "./interfaces/IFeeController.sol";

contract ReaperZeroFeeController is IFeeController {
    function fetchManagementFeeBPS() external view returns (uint16) {
        return 0;
    }

    function updateManagementFeeBPS(uint16 _feeBPS) external {}
}