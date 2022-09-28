// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {ClimberVault} from "./ClimberVault.sol";

/**
 * @title ClimberVaultV2
 * @dev New implementation.
 * @author dec3ntraliz3d
 */
contract ClimberVaultV2 is ClimberVault {
    // This implementation adds a new function to change proposer via an
    // external function.
    function setSweeper(address _newSweeper) external {
        _setSweeper(_newSweeper);
    }
}
