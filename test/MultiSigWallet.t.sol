// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";


contract MultiSigWalletTest is Test {

    MultiSigWallet public multiSigWallet;
    address public owner1;
    address public owner2;
    address public owner3;
    address public otherAccount;
    address[] public owners;
    uint256 public requiredConfirmations;

    function setUp() public {
        owner1 = address(1);
        owner2 = address(2);
        owner3 = address(3);
        otherAccount = address(4);

        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        requiredConfirmations = 2;

        multiSigWallet = new MultiSigWallet(owners, requiredConfirmations);
    }

    function testConstructor() public {
        assertEq(multiSigWallet.owners(0), owner1, "Owner1 not correctly set");
        assertEq(multiSigWallet.owners(1), owner2, "Owner2 not correctly set");
        assertEq(multiSigWallet.owners(2), owner3, "Owner3 not correctly set");
        assertEq(multiSigWallet.requiredConfirmations(), requiredConfirmations, "Required confirmations not correctly set");
    }

    function testIsOwner() public {
        assertTrue(multiSigWallet.isOwner(owner1), "Owner1 should be recognized");
        assertTrue(multiSigWallet.isOwner(owner2), "Owner2 should be recognized");
        assertTrue(multiSigWallet.isOwner(owner3), "Owner3 should be recognized");
        assertFalse(multiSigWallet.isOwner(otherAccount), "OtherAccount should not be recognized");
    }

    function testSubmitTransaction() public {
        vm.prank(owner1);
        uint256 transactionId = multiSigWallet.submitTransaction(otherAccount, 1 ether, "");
        assertEq(multiSigWallet.getTransactionCount(), 1, "Transaction count should be 1");
        MultiSigWallet.Transaction memory transaction = multiSigWallet.getTransaction(transactionId);
        assertTrue(transaction.destination == otherAccount, "Destination address incorrect");

    }

    function testSubmitTransaction_NotOwner() public {
      vm.prank(otherAccount);
      vm.expectRevert("Not an owner");
      multiSigWallet.submitTransaction(otherAccount, 1 ether, "");
    }

    function testConfirmTransaction() public {
        vm.prank(owner1);
        uint256 transactionId = multiSigWallet.submitTransaction(otherAccount, 1 ether, "");

        vm.prank(owner2);
        multiSigWallet.confirmTransaction(transactionId);

        assertEq(multiSigWallet.getConfirmationCount(transactionId), 1, "Confirmation count should be 1");
        assertTrue(multiSigWallet.confirmations(transactionId, owner2), "Owner2 should have confirmed");
    }

    function testExecuteTransaction() public {
        // payable(address(multiSigWallet)).transfer(3 ether);
        uint256 initialBalance = address(this).balance;

        vm.prank(owner1);
        uint256 transactionId = multiSigWallet.submitTransaction(address(this), 1 ether, "");

        vm.prank(owner1);
        multiSigWallet.confirmTransaction(transactionId);
        vm.prank(owner2);
        multiSigWallet.confirmTransaction(transactionId);

        uint256 finalBalance = address(this).balance;
        assertEq(finalBalance - initialBalance, 1 ether, "Transaction should have executed");
				MultiSigWallet.Transaction memory transaction = multiSigWallet.getTransaction(transactionId);
        assertTrue(transaction.executed, "Transaction should be marked as executed");

    }

     function testExecuteTransaction_Revert() public {
        vm.prank(owner1);
        uint256 transactionId = multiSigWallet.submitTransaction(address(this), 1 ether, "0x");

        vm.prank(owner1);
        multiSigWallet.confirmTransaction(transactionId);
        vm.prank(owner2);
        multiSigWallet.confirmTransaction(transactionId);
				
        vm.expectEmit(false, false, false, true);
        emit MultiSigWallet.ExecutionFailure(transactionId);
    }

}