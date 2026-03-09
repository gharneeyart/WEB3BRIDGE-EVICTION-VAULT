// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "./MerkleProofHandler.sol";
import "./EmergencyFunctions.sol";

contract EvictionVault is MerkleProofHandler {
    mapping(address => uint256) public balances;
    uint256 public totalVaultValue;
    mapping(uint256 => bool) public isPauseTx;
    mapping(uint256 => bool) public isUnpauseTx;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);

    event EmergencyWithdrawal(address indexed recipient, uint256 amount);

    constructor(address[] memory _owners, uint256 _threshold) payable MerkleProofHandler(_owners, _threshold) {
        totalVaultValue = msg.value;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        totalVaultValue -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawal(msg.sender, amount);
    }

    function verifySignature(address signer, bytes32 messageHash, bytes memory signature) external pure returns (bool) {
        return ECDSA.recover(messageHash, signature) == signer;
    }

    function submitEmergencyWithdrawAll() external onlyOwner {
        uint256 id = txCount++;
        transactions[id] = Transaction({
            to: address(this),
            value: 0,
            data: abi.encodeWithSignature("emergencyWithdrawAll()"),
            executed: false,
            confirmations: 0,
            submissionTime: block.timestamp,
            executionTime: 0
        });
        confirmed[id][msg.sender] = true;
        transactions[id].confirmations = 1;

        if (threshold == 1) {
            transactions[id].executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        emit Submission(id);
    }

    function emergencyWithdrawAll() external {
        require(msg.sender == address(this), "Only via multisig");
        require(address(this).balance > 0, "No balance");

        uint256 amount = address(this).balance;
        totalVaultValue = 0;

        uint256 share = amount / owners.length;
        for (uint256 i = 0; i < owners.length; i++) {
            (bool success,) = payable(owners[i]).call{value: share}("");
            require(success, "Transfer failed");
            emit EmergencyWithdrawal(owners[i], share);
        }
    }
}
