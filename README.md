# 9M ERC721 Smart Contract
9M ERC721 (mint, renew) NFT smart contract

This smart contract is what powers https://9m.ai/
A decentralized store for obtaining virtual machines to run modded servers on.

## Promises
The following are promises this ERC721 smart contract aims to accomplish:
1. Allows users to mint a unique NFT that can be transferred that represents a virtual machine classification
2. Each NFT represents a virtual machine abstract and allows token holder authorization to control it
3. Virtual machine NFT representations have a set expiration date
4. Allows users to renew virtual machines using NFT ownership, days and hardware classification determines price in wei
5.  Allows smart contract owner to set price in wei (ether / 1e18) per virtual machine hardware classification

## How does it work

**ERC-721 certificate contract** — This is a standard ERC-721 contract implemented using the [0xcert template](https://github.com/0xcert/ethereum-erc721/tree/master/contracts/tokens) with additional functions:

### Write functions
* `create(uint256 vm_classifier, uint256 days_) external payable returns (uint)` — Allows anybody to create a certificate (NFT) payable in wei based on a virtual machine hardware classification identifier and number of days it is valid for.
* `renewVM(uint256 token_id, uint256 days_) external payable` — Allows anybody to renew a existing virtual machine based on its token identifier and number of days to add from current date.

* `setBaseURI(string calldata baseURI_) external onlyOwner` — Allows the smart contract owner to set a base domain prefix for the `tokenURI` function.
* `setMintingPrice(uint vm_classifier, uint vm_price) onlyOwner` — Allows the smart contract owner to set a price rate in wei (ether / 1e18) for cost of virtual machine hardware identifier to be rented for a single day.

### Read functions
* `tokenURI(uint256 tokenId) view` — Returns a URL that contains additional metadata about the virtual machine.
* `getVMType(uint token_id) view` — Returns an existing virtual machine hardware identifier.
* `getExpiry(uint token_id) view` — Returns an existing virtual machine expiration timestamp.
* `mintingPrice(uint vm_classifier, uint256 days_) view` — Returns the price in wei (ether / 1e18) based on the number of days and virtual machine hardware classification to mint, same value should be used in `create` function via `msg.value`. 

## Using mainnet
The following contract addresses can be found on the Ethereum mainnet
* 9M-ERC721: [0x4C3968d642427831301E88B4ae5AaEe247223ed0](https://etherscan.io/address/0x4c3968d642427831301e88b4ae5aaee247223ed0#code)

## Using our site
Install MetaMask and visit https://9m.ai/ to create an account and interact with the smart contract.

## How to deploy
Clone this repository and use remix to compile and deploy both .sol source files.

## Attribution
Smart contract additional functions by [twit:@037](https://twitter.com/037) / [git:@649](https://github.com/649)

## To do
This section is a list of tasks that are pending. You're more than free to help and contribute to this project by creating a pull request.
* Proxy smart contract that offers discounts on VM listings by considering number of hours previously rented
* Proxy smart contract relay that pays for gas fees