// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Multisigs {
    error NOT_OWNER();
    error ALREADY_CONFIRMED();
    error ALREADY_EXECUTED();
    error NOT_ENOUGH_CONFIRMATIONS();
    error TIMELOCK_NOT_ELAPSED();

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }

    address[] public owners;
    uint256 public threshold;
    uint256 public txCount;

    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Transaction) public transactions;

    uint256 public constant TIMELOCK_DURATION = 1 hours;

    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);

    constructor(address[] memory _owners, uint256 _threshold) payable {
        require(_owners.length > 0, "no owners");
        require(_threshold > 0 && _threshold <= _owners.length, "invalid threshold");
        threshold = _threshold;

        for (uint i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0), "zero address owner");
            require(!isOwner[o], "duplicate owner");
            isOwner[o] = true;
            owners.push(o);
        }
    }

    // ✅ Fix 1: inverted logic was blocking owners — != true means non-owners passed
    modifier onlyOwner {
        if (!isOwner[msg.sender]) revert NOT_OWNER();
        _;
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner {
        uint256 id = txCount++;
        transactions[id] = Transaction({
            to: to,
            value: value,
            data: data,
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

    function confirmTransaction(uint256 txId) external onlyOwner {
        Transaction storage txn = transactions[txId];
        if (txn.executed) revert ALREADY_EXECUTED();
        if (confirmed[txId][msg.sender]) revert ALREADY_CONFIRMED();

        confirmed[txId][msg.sender] = true;
        txn.confirmations++;

        // ✅ Fix 3: set timelock the moment threshold is reached
        if (txn.confirmations == threshold) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external virtual onlyOwner {
        Transaction storage txn = transactions[txId];
        if (txn.confirmations < threshold) revert NOT_ENOUGH_CONFIRMATIONS();
        if (txn.executed) revert ALREADY_EXECUTED();
        if (block.timestamp < txn.executionTime) revert TIMELOCK_NOT_ELAPSED();

        txn.executed = true;
        (bool s,) = txn.to.call{value: txn.value}(txn.data);
        require(s, "execution failed");

        emit Execution(txId);
    }
}
