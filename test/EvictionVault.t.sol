// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EvictionVault} from "../src/EvictionVault.sol";

contract EvictionVaultTest is Test {
    EvictionVault evault;

    address internal halimah;
    address internal afeez;
    address internal ganiyat;
    address internal mcdavid;

    function setUp() public {
        halimah  = makeAddr("Halimah");
        afeez    = makeAddr("Afeez");
        ganiyat  = makeAddr("Ganiyat");
        mcdavid  = makeAddr("McDavid");

        address[] memory owners = new address[](5);
        owners[0] = halimah;
        owners[1] = afeez;
        owners[2] = ganiyat;
        owners[3] = mcdavid;
        owners[4] = address(this);

        evault = new EvictionVault(owners, 3); 

        vm.deal(halimah, 10 ether);
        vm.deal(afeez, 10 ether);
        vm.deal(ganiyat, 10 ether);
        vm.deal(mcdavid, 10 ether);
        vm.deal(address(this), 10 ether);
    }

    function testDeposit() public {
        evault.deposit{value: 1 ether}();

        assertEq(address(evault).balance, 1 ether);
        assertEq(evault.balances(address(this)), 1 ether);
        assertEq(evault.totalVaultValue(), 1 ether);
    }

    function testWithdraw() public {
        evault.deposit{value: 2 ether}();

        uint256 balBefore = address(this).balance;
        evault.withdraw(1 ether);

        assertEq(evault.balances(address(this)), 1 ether);
        assertEq(address(this).balance, balBefore + 1 ether);
    }


    function testWithdraw_RevertIfPaused() public {
        evault.deposit{value: 1 ether}();

        evault.submitPause();

        vm.prank(afeez);
        evault.confirmTransaction(0);

        vm.prank(ganiyat);
        evault.confirmTransaction(0); 

        vm.warp(block.timestamp + 1 hours + 1);

        evault.executeTransaction(0);

        assertTrue(evault.paused(), "vault should be paused after execution");

        vm.expectRevert("Contract is paused");
        evault.withdraw(1 ether);
    }

    function testUnpause_RequiresMultisig() public {
        evault.submitPause();                  

        vm.prank(afeez);
        evault.confirmTransaction(0);  

        vm.prank(ganiyat);
        evault.confirmTransaction(0);          

        vm.warp(block.timestamp + 1 hours + 1);
        evault.executeTransaction(0);
        assertTrue(evault.paused(), "should be paused");

        vm.expectRevert("Only via multisig");
        evault.unpause();

        evault.submitUnpause();                 

        vm.prank(afeez);
        evault.confirmTransaction(1);           

        vm.prank(mcdavid);
        evault.confirmTransaction(1);          

        vm.warp(block.timestamp + 1 hours + 1);
        evault.executeTransaction(1);
        assertFalse(evault.paused(), "should be unpaused");
    }

    function testEmergencyWithdrawAll() public {
        evault.deposit{value: 5 ether}();

        uint256 halimahBefore = halimah.balance;

        evault.submitEmergencyWithdrawAll();

        vm.prank(afeez);
        evault.confirmTransaction(0);          
        vm.prank(ganiyat);
        evault.confirmTransaction(0);           

        vm.warp(block.timestamp + 1 hours + 1);
        evault.executeTransaction(0);

        assertEq(address(evault).balance, 0,   "vault should be empty");
        assertEq(evault.totalVaultValue(), 0,  "totalVaultValue should be zero");

        assertGt(halimah.balance, halimahBefore, "halimah should have received a share");
    }

    function testEmergencyWithdrawAll_CannotCallDirectly() public {
        evault.deposit{value: 1 ether}();

        vm.expectRevert("Only via multisig");
        evault.emergencyWithdrawAll();
    }

    receive() external payable {}
}
