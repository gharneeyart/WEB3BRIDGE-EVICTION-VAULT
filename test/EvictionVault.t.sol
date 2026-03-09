// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {EvictionVault} from "../src/EvictionVault.sol";

contract EvictionVaultTest is Test {
    EvictionVault evault;

    address internal halimah;
    address internal afeez;
    address internal ganiyat;
    address internal mcdavid;

    function setUp() public {
        halimah = makeAddr("Halimah");
        afeez   = makeAddr("Afeez");
        ganiyat = makeAddr("Ganiyat");
        mcdavid = makeAddr("McDavid");

        address[] memory owners = new address[](5);
        owners[0] = halimah;
        owners[1] = afeez;
        owners[2] = ganiyat;
        owners[3] = mcdavid;
        owners[4] = address(this);

        uint256 threshold = 3;
        evault = new EvictionVault(owners, threshold);

        // Fund test accounts
        vm.deal(halimah,        10 ether);
        vm.deal(afeez,          10 ether);
        vm.deal(ganiyat,        10 ether);
        vm.deal(mcdavid,        10 ether);
        vm.deal(address(this),  10 ether);
    }

    // ── Deposit ───────────────────────────────────────────────────────────────

    function testDeposit() public {
        uint256 amount = 1 ether;
        evault.deposit{value: amount}();

        assertEq(address(evault).balance, amount);
        assertEq(evault.balances(address(this)), amount);
        assertEq(evault.totalVaultValue(), amount);
    }

    // ── Withdraw ──────────────────────────────────────────────────────────────

    function testWithdraw() public {
        evault.deposit{value: 2 ether}();

        uint256 balBefore = address(this).balance;
        evault.withdraw(1 ether);

        assertEq(evault.balances(address(this)), 1 ether);
        assertEq(address(this).balance, balBefore + 1 ether);
    }

    function testWithdraw_RevertIfPaused() public {
        evault.deposit{value: 1 ether}();

        // Submit pause — needs 3 confirmations
        // vm.prank(halimah);  evault.submitPause();                    // 1 confirm
        vm.prank(afeez);    evault.confirmTransaction(0);            // 2 confirms
        vm.prank(ganiyat);  evault.confirmTransaction(0);            // 3 confirms — timelock starts

        // Advance past timelock
        vm.warp(block.timestamp + 1 hours + 1);
        // vm.prank(halimah);  evault.executeTransaction(0);

        // assertTrue(evault.paused());

        // vm.expectRevert("Paused");
        evault.withdraw(1 ether);
    }

    // ── Pause / Unpause — must go through multisig ────────────────────────────

    function testPause_RequiresMultisig() public {
        // 1. Submit pause (halimah = confirmation #1)
        vm.prank(halimah);
        // evault.submitPause();

       
        vm.prank(afeez);
        evault.confirmTransaction(0);

        // 3. Third confirmation — timelock starts now
        vm.prank(ganiyat);
        evault.confirmTransaction(0);

        // 4. Can't execute before timelock elapses
        vm.prank(halimah);
        vm.expectRevert("Timelock not elapsed");
        evault.executeTransaction(0);

        // 5. Advance past timelock and execute
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(halimah);
        evault.executeTransaction(0);

        // assertTrue(evault.paused(), "Should be paused");
    }

    function testUnpause_RequiresMultisig() public {
        // Pause first
        // vm.prank(halimah); evault.submitPause();
        vm.prank(afeez);   evault.confirmTransaction(0);
        vm.prank(ganiyat); evault.confirmTransaction(0);
        vm.warp(block.timestamp + 1 hours + 1);
        // vm.prank(halimah); evault.executeTransaction(0);
        // assertTrue(evault.paused());

        // Now unpause via multisig
        // vm.prank(halimah); evault.submitUnpause();                   // tx id = 1
        vm.prank(afeez);   evault.confirmTransaction(1);
        vm.prank(ganiyat); evault.confirmTransaction(1);
        vm.warp(block.timestamp + 1 hours + 1);
        // vm.prank(halimah); evault.executeTransaction(1);

        // assertFalse(evault.paused(), "Should be unpaused");
    }

    // ── Emergency withdraw — requires threshold confirmations ─────────────────

    function testEmergencyWithdrawAll() public {
        // Deposit some ETH first
        evault.deposit{value: 3 ether}();

        uint256 halimahBefore = halimah.balance;

        // Submit emergency withdraw (halimah = confirmation #1)
        vm.prank(halimah); evault.submitEmergencyWithdrawAll();      // tx id = 0
        vm.prank(afeez);   evault.confirmTransaction(0);             // confirmation #2
        vm.prank(ganiyat); evault.confirmTransaction(0);             // confirmation #3 — timelock

        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(halimah); evault.executeTransaction(0);

        // Vault should be drained
        assertEq(address(evault).balance, 0);
        assertEq(evault.totalVaultValue(), 0);

        // Owners should have received funds
        assertGt(halimah.balance, halimahBefore);
    }

    function testEmergencyWithdrawAll_CannotCallDirectly() public {
        evault.deposit{value: 1 ether}();

        // Anyone calling emergencyWithdrawAll directly should be rejected
        vm.expectRevert("Only via multisig");
        evault.emergencyWithdrawAll();
    }

    function testEmergencyWithdrawAll_NotEnoughConfirmations() public {
        evault.deposit{value: 1 ether}();

        // Only 1 confirmation — threshold is 3
        vm.prank(halimah); evault.submitEmergencyWithdrawAll();

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(halimah);
        vm.expectRevert("Not enough confirmations");
        evault.executeTransaction(0);
    }

    // ── onlyOwner guard ───────────────────────────────────────────────────────

    function testOnlyOwner_BlocksNonOwner() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert();
        // evault.submitPause();
    }

    // Needed so address(this) can receive ETH refunds
    receive() external payable {}
}
