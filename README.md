# CodeforDAO Contracts

> **This project is a work in progress, it has not been audited for code security and is being deployed in local development and test networks and is not gas optimized at this time. Please use with caution.**

The CodeforDAO contract is a set of DAO infrastructure and efficiency tools with member NFT at its core.

It is centered on a set of membership contracts for the `ERC721` protocol, the creation of its counterpart share contracts, two parallel governance frameworks and a timelock vault contract.

It introduces some basic features to DAO, including vault contracts for self-service participation in investments, a set of modular frameworks to support aggressive governance.

## Core Concepts

We believe that DAO will be a very powerful tool and, for now, it has become an important concept trusted by developers worldwide and by a large number of users familiar with Web3. Many people who are unfamiliar with each other are spread all over the world, but are contributing to a DAO at the same time.

But we have to admit that, at the moment, while DAO has achieved an important foundation of trust, its infrastructure is still very imperfect, especially in terms of efficiency tools, and we cannot guarantee that DAO will be able to run continuously and efficiently like any large organization, such as a traditional shareholding company. This is exactly what CodeforDAO aims to do.

By improving aggressive governance, and continuously contributing infrastructure and modules to the DAO, and even introducing AI automated governance, we hope to take the DAO to a new level of efficiency.

## Structures

This is a brief introduction to the structure of the contract, if you are interested in more, please read our contract code, which is located in the contracts folder.

### Membership

The Member Contract is the entry point for other subcontracts, and it is an `ERC721` contract. It includes a simple whitelist invitation function and provides the investMint method to ensure that external investors get a corresponding membership (similar to a board of managers)

### Share

The share contract is a simple `ERC20` full-featured contract, the ownership of which will be delegated to the vault contract upon creation

### Treasury

After the initialization function is completed, the vault contract is the owner of all contracts. It stores all the assets and contract permissions of the DAO. It provides an invest method that allows external investors to participate in the financing of the DAO and issues corresponding shares for these investors. The vault contract also operates with a specific module, which is authorized to use some of the assets for the daily management of the DAO.

### Governor

The governance contract allows voting using `ERC721` and `ERC20`, after the initialization function is completed we will have two governance contracts, one supporting voting using the member NFT (1:1) it's role is similar to the founding team voting and the other supporting voting using shares (similar to class B shares on the board)

### Module

The core module contract provides a set of methods that allow modules and vaults to interact. At the same time, it is an actively governed multi-signature contract that allows proposing, confirming, scheduling and executing module-related operations, and you can see the usage of these hook functions in specific modules.

## Get started

In order to start developing, you must be familiar with some basic knowledge of smart contracts and install the corresponding development environment.

```bash
$ npm install
```

### Running tests

```bash
$ npm run test
```

Running spec tests where you can find them in `./test` folder

```bash
$ npm run test:membership
```
