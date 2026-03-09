## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```





setMerkleRoot Callable by Anyone
Added onlyOwner modifier in the multisigs contract, then merkle proof handler inherits it which make it have access to the modifier, then i added it to the setMerkleProof function.

receive() uses tx.orign but changed it to msg.sender
tx.origin is the original EOA, if a contract deposits on behalf of a user.
tx.origin credits the EOA, not the contract.

withdraw and claim uses transfer
I changed it to use .call instead of .transfer because .transfer has a 2300 gas limit which can fail for smart contract recipients

emergencyWithdrawAll() public drain was accessible to anyone, it uses transfer, 
The modification i made was to make sure the emergency withdraw function was submitted using the submitEmergencyWithdrawAll() for all required signers to confirm the