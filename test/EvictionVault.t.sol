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

    function testDeposit() public {
        uint256 amount = 1 ether;
        evault.deposit{value: amount}();

        assertEq(address(evault).balance, amount);
        assertEq(evault.balances(address(this)), amount);
        assertEq(evault.totalVaultValue(), amount);
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
             
        vm.prank(afeez);    evault.confirmTransaction(0);            
        vm.prank(ganiyat);  evault.confirmTransaction(0);           

   
        vm.warp(block.timestamp + 1 hours + 1);
    
        evault.withdraw(1 ether);
    }

    function testUnpause_RequiresMultisig() public {
       
        vm.prank(afeez);   evault.confirmTransaction(0);
        vm.prank(ganiyat); evault.confirmTransaction(0);
        vm.warp(block.timestamp + 1 hours + 1);
       
        vm.prank(afeez);   evault.confirmTransaction(1);
        vm.prank(ganiyat); evault.confirmTransaction(1);
        vm.warp(block.timestamp + 1 hours + 1);
       
       
    }

  
    function testEmergencyWithdrawAll() public {
        evault.deposit{value: 3 ether}();

        uint256 halimahBefore = halimah.balance;

      
        vm.prank(halimah); evault.submitEmergencyWithdrawAll();      
        vm.prank(afeez);   evault.confirmTransaction(0);             
        vm.prank(ganiyat); evault.confirmTransaction(0);             

        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(halimah); evault.executeTransaction(0);

       
        assertEq(address(evault).balance, 0);
        assertEq(evault.totalVaultValue(), 0);

        assertGt(halimah.balance, halimahBefore);
    }

    function testEmergencyWithdrawAll_CannotCallDirectly() public {
        evault.deposit{value: 1 ether}();

       
        vm.expectRevert("Only via multisig");
        evault.emergencyWithdrawAll();
    }

    receive() external payable {}
}
