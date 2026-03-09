// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Multisig.sol";

contract EmergencyFunctions is Multisigs {
    bool public paused;

    mapping(uint256 => bool) public isPauseTx;
    mapping(uint256 => bool) public isUnpauseTx;

    event Paused();
    event Unpaused();

    constructor(address[] memory _owners, uint256 _threshold)
        Multisigs(_owners, _threshold) {}

    function submitPause() external onlyOwner {
        uint256 id = txCount++;
        transactions[id] = Transaction({
            to: address(this),
            value: 0,
            data: abi.encodeWithSignature("pause()"),
            executed: false,
            confirmations: 0,   // ✅ start at 0
            submissionTime: block.timestamp,
            executionTime: 0
        });
        confirmed[id][msg.sender] = true;
        transactions[id].confirmations = 1;
        isPauseTx[id] = true;

        if (threshold == 1) {
            transactions[id].executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        emit Submission(id);
    }

    function submitUnpause() external onlyOwner {
        uint256 id = txCount++;
        transactions[id] = Transaction({
            to: address(this),
            value: 0,
            data: abi.encodeWithSignature("unpause()"),
            executed: false,
            confirmations: 0,   // ✅ start at 0
            submissionTime: block.timestamp,
            executionTime: 0
        });
        confirmed[id][msg.sender] = true;
        transactions[id].confirmations = 1;
        isUnpauseTx[id] = true;

        if (threshold == 1) {
            transactions[id].executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        emit Submission(id);
    }

    // ✅ Fix 4: internal — cannot be called directly from outside, only via executeTransaction
    function pause() internal {
        require(!paused, "Already paused");
        paused = true;
        emit Paused();
    }

    function unpause() internal {
        require(paused, "Not paused");
        paused = false;
        emit Unpaused();
    }

    // Override executeTransaction to handle pause/unpause routing
    function executeTransaction(uint256 txId) external virtual override onlyOwner {
        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= threshold, "Not enough confirmations");
        require(!txn.executed, "Already executed");
        require(block.timestamp >= txn.executionTime, "Timelock not elapsed");
        require(txn.executionTime != 0, "Timelock not started");

        txn.executed = true;

        // Route pause/unpause internally instead of using .call
        // This prevents anyone from crafting a tx that calls pause() directly
        if (isPauseTx[txId]) {
            pause();
        } else if (isUnpauseTx[txId]) {
            unpause();
        } else {
            (bool s,) = txn.to.call{value: txn.value}(txn.data);
            require(s, "execution failed");
        }

        emit Execution(txId);
    }
}
