<p align="center">
  <a href="https://twitter.com/codefordao"><img src="https://avatars.githubusercontent.com/u/97301607?s=200&u=d0a9f88d13d7d7dd5b37c09fdd802c9fe378d029&v=4"/></a>
</p>
<h2 align="center">
  CodeforDAO Contracts
</h2>
<p align="center">
  Base on, build upon and code for DAOs.
</p>
<p align="center">
  Make DAO the next generation of productivity tools for global collaboration.
</p>
<p align="center">
  Follow us on Twitter <a href="https://twitter.com/codefordao">@codefordao</a>.
</p>

<p align="center">
  <a href="https://github.com/CodeforDAO/contracts/">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="mit license"/>
  </a>
</p>

> **This project is a work in progress, it has not been audited for code security and is being deployed in local development and test networks and is not gas optimized at this time. Please use with caution.**

The CodeforDAO contract is a set of DAO infrastructure and efficiency tools with member NFT at its core.

It is centered on a set of membership contracts for the `ERC721` protocol, the creation of its counterpart share contracts, two parallel governance frameworks and a timelock vault contract.

It introduces some basic features to DAO, including vault contracts for self-service participation in investments, a set of modular frameworks to support aggressive governance.

## Core Concepts

We believe that DAO will be a very powerful tool and, for now, it has become an important concept trusted by developers worldwide and by a large number of users familiar with Web3. Many people who are unfamiliar with each other are spread all over the world, but are contributing to a DAO at the same time.

But we have to admit that, at the moment, while DAO has achieved an important foundation of trust, its infrastructure is still very imperfect, especially in terms of efficiency tools, and we cannot guarantee that DAO will be able to run continuously and efficiently like any large organization, such as a traditional shareholding company. This is exactly what CodeforDAO aims to do.

By improving aggressive governance, and continuously contributing infrastructure and modules to the DAO, and even introducing AI automated governance, we hope to take the DAO to a new level of efficiency.

## Structures

This is a brief introduction to the structure of the contract, if you are interested in more, please read our contract code, which is located in the `./contracts` folder.

### Membership

The Member Contract is the entry point for other subcontracts, and it is an `ERC721` contract. It includes a simple whitelist invitation function and provides the `investMint(to)` method to ensure that external investors get a corresponding membership (similar to a board of managers)

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

**Note:** these smart contracts are not designed to be library contracts, and you can fork these contracts locally to modify them yourself, rather than importing them directly by a git link.

### Membership NFT

Currently, the membership NFT contract (`contracts/contracts/core/Membership.sol`) is the entry point for all contracts and the creator of all contracts.

This means that deploying this contract will deploy a full set of DAO governance contracts, including the vault, an ERC20 token contract, and two sets of governance contracts.

After deployment, you need to call the `setupGovernor` method to release important permissions and hand them over to the vault contract, which secures the governance of the DAO.

**Note:** In the future, the way the membership contract is initialized may change, and in order to optimize gas fees, we may modify it to allow external scripts to modify permissions.

Run the `npm run deploy:test` command to deploy the contract, or you can refer to the `. /tests` folder for test cases.

### Extending Modules

Modules are an important part of aggressive governance. By writing your own modules, you can expand any business to be part of DAO.

Using the `Payroll` module as an example, we can take a look at how to write our own module.

```solidity
contract Payroll is Module {
  using Strings for uint256;
  using Address for address payable;

  constructor(
    address membership,
    uint256[] memory operators,
    uint256 delay
  ) Module('Payroll', 'Payroll Module V1', membership, operators, delay) {}
}

```

By inheriting from the core module, Payroll needs to initialize the constructor of the core module, which will automatically get a timelock contract `payroll.timelock()`.

The module must pass three parameters, which are the address of the member NFT contract, the list of operator IDs (NFT tokenID) and the time for which the time lock delay proposal will be executed.

You can easily define structured data and events in the module.

```solidity
struct PayrollDetail {
  uint256 amount;
  PayrollType paytype;
  PayrollPeriod period;
  PayrollInTokens tokens;
}

event PayrollAdded(uint256 indexed memberId, PayrollDetail payroll);
event Payrollscheduled(uint256 indexed memberId, bytes32 proposalId);

mapping(uint256 => mapping(PayrollPeriod => PayrollDetail[])) private _payrolls;
```

The application module must perform the proposal function of the core module; simply put, it must implement an external method to allow operators to make proposals.

```solidity
/**
 * @dev Schedule Payroll
 * Adding a member's compensation proposal to the compensation cycle
 */
function schedulePayroll(uint256 memberId, PayrollPeriod period)
  public
  onlyOperator
  returns (bytes32 _proposalId)
{
  // Create proposal payload
  PayrollDetail[] memory payrolls = GetPayroll(memberId, period);
  address[] memory targets = new address[](payrolls.length);
  uint256[] memory values;
  bytes[] memory calldatas;
  string memory description = string(
    abi.encodePacked(
      _payrollPeriods[uint256(period)],
      ' Payroll for #',
      memberId.toString(),
      '(',
      _payrollTypes[uint256(payrolls[0].paytype)],
      ')',
      '@',
      block.timestamp.toString()
    )
  );

  // You can use the methods of the core module to get the corresponding address
  address memberWallet = getAddressByMemberId(memberId);

  for (uint256 i = 0; i < payrolls.length; i++) {
    PayrollDetail memory payroll = payrolls[i];
    targets[i] = address(this);
    values[i] = payroll.amount;

    // Fullfill proposal payload calldatas
    calldatas[i] = abi.encodeWithSignature(
      'execTransfer(address,address[],uint256[])',
      memberWallet,
      payroll.tokens.tokens,
      payroll.tokens.amounts
    );
  }

  // Propose It.
  _proposalId = propose(targets, values, calldatas, description);

  // Trigger your event
  emit Payrollscheduled(memberId, _proposalId);
}

```

Correspondingly, the application module sea needs to implement specific proposal execution methods. In this case, the method is `execTransfer`.

Check the [Payroll module](./contracts/modules/Payroll.sol) to see the detail implementation.

By default, proposals in the module need to be confirmed by all operators before they can enter the queue and wait for execution. Its lifecycle must go through four stages: proposal, confirm, queue and execution. Since it is aggressively governed, module proposals do not need to go through a full DAO vote.

The application module's timelock contract allows the use of the vault's assets within certain limits, and you can license and invoke these assets with `approveModulePayment()` and `pullModulePayment()` in the vault contract. `pullPayments()` method in core module is also useful.

**Notice**: `approveModulePayment()` require a vote of the DAO

### Running tests

This project currently uses `hardhat-deploy` for multiple environment deployments and to increase the speed of testing.

```bash
$ npm run test
```

Running spec tests where you can find them in `./test` folder

```bash
$ npm run test:membership
```

or

```bash
$ npm run test:governor
```

If you need a test coverage report:

```bash
$ npm run test:coverage
```

### About Gas optimization

The contract code in this project is not currently systematically gas optimized, so they will be quite expensive to deploy on the eth mainnet. At this point, we do not recommend that using them on the mainnet.

As a result, the base libraries that the contract code in this project relies on will change very frequently and may be replaced by more efficient libraries, but we will try to find a balance between audited reliable contracts and efficiency.

### MIT license

Copyright (c) 2022 CodeforDAO &lt;contact@codefordao.org&gt;

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
