## Eviction Vault

## setMerkleRoot Callable by Anyone

Added onlyOwner modifier in the multisigs contract, then merkle proof handler inherits it which make it have access to the modifier, then i added it to the setMerkleProof function.

## receive() uses tx.orign but changed it to msg.sender
tx.origin is the original EOA, if a contract deposits on behalf of a user.
tx.origin credits the EOA, not the contract.

## withdraw and claim uses transfer
I changed it to use .call instead of .transfer because .transfer has a 2300 gas limit which can fail for smart contract recipients

### emergencyWithdrawAll() public drain
emergencyWithdrawAll() public drain was accessible to anyone, it uses transfer, 
The modification i made was to make sure the emergency withdraw function was submitted using the submitEmergencyWithdrawAll() for all required signers to confirm the

