# Eviction Vault - Bugs & Fixes

## setMerkleRoot Callable by Anyone
Anyone(public or owners) can set the merkle root in a multi signer contract.
### The Solution
Added onlyOwner modifier in the multisigs contract, which will be any of the set owners.
### The Implementation
I added onlyOwner() modifier that has the condition to check if the msg.sender is one of the set owners in the multisig contract. Then, MerkleproofHandler contract inherits it from EmergencyFunction contract which inherits the multisigs contract directly. With this the onlyOwner modifier was accessible then i added it to the setMerkleProof function.


## receive() uses tx.orign but changed it to msg.sender
tx.origin is the original EOA, if a contract deposits on behalf of a user.
tx.origin credits the EOA, not the contract.

## withdraw and claim uses transfer
I changed it to use .call instead of .transfer because .transfer has a 2300 gas limit which can fail for smart contract recipients

## emergencyWithdrawAll() public drain
1. No access control
2. It uses transfer
3. One person gets to drain the funds to personal account
### The Solution
The modification i made was to make sure the emergency withdraw function was submitted using the submitEmergencyWithdrawAll() function where the threshold needs to be met before the emergencyWithdrawAll() function can be called, now it's only callable via the multisig execute flow
### The Implementation
1. Created submitEmergencyWithdrawAll() function which i added access control to, the onlyOwner() modifier.
2. Then, the  emergengency withdrawal transaction is stored in the Transaction struct. The to address is set to the address of the contract and the data field is set to emergencyWithdrawAll() function. When this transaction eventually executes, it will call the vault's own emergencyWithdrawAll() function. The vault calls itself. That's how the access control on emergencyWithdrawAll() works, only address(this) can call it, and the only way to get msg.sender == address(this) is through this multisig path.
3. The submitter automatically counts as the first confirmation but the confirmation threshold needs to be met before the exectionTime starts.
4. emergencyWithdrawAll() shares the balance among the owners of the contract equally by dividing the balance with the owners length, that's why it's a multisig, the funds should not be going to one person.
5. I changed the .transfer to .call.

## `pause` / `unpause` Single Owner Control

# timelock
set timelock the moment threshold is reached



