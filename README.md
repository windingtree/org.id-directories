[![Build Status](https://travis-ci.org/windingtree/wt-contracts.svg?branch=master)](https://travis-ci.org/windingtree/wt-contracts)
[![Coverage Status](https://coveralls.io/repos/github/windingtree/wt-contracts/badge.svg?branch=master)](https://coveralls.io/github/windingtree/wt-contracts?branch=master&v=2.0) [![Greenkeeper badge](https://badges.greenkeeper.io/windingtree/wt-contracts.svg)](https://greenkeeper.io/)

# WT Smart Contracts

Smart contracts of the Winding Tree platform.


## Documentation

![](https://raw.githubusercontent.com/windingtree/wt-contracts/69fd8a5f9dcc08056b3c4e496e4eb8bb62c46896/assets/contracts-schema.png)

Generated documentation is in the [`docs`](https://github.com/windingtree/wt-contracts/tree/master/docs)
folder and can be generated by running `npm run soldoc`.

There are two main groups of users in the Winding Tree platform - content producers (e. g. Hotels, Airlines)
and content consumers (e. g. OTAs (Online Travel Agencies)).

### Content producers

When a producer wants to participate, they have to do the following:

1. Locate Winding Tree Entrypoint address
1. Locate the appropriate Segment Directory address
1. Prepare off-chain data conforming to the [specification](https://github.com/windingtree/wt-organization-schemas)
1. Register their organization
    1. Fully custom
        1. Create an implementation of `OrganizationInterface` smart contract.
        1. Deploy the custom implementation.
        1. Call `add` method on the appropriate Segment Directory.
    1. Assisted
        1. Locate Organization Factory address from Entrypoint
        1. Call `create` method on the Organization Factory with the URI of off-chain data.
        Organization smart contract that belongs to the transaction sender is created.
        1. Call `add` method on the appropriate Segment Directory.

The Organization created in `OrganizationFactory` uses the
[Upgradeability Proxy pattern](https://docs.zeppelinos.org). In short, the Factory owner will keep
the ownership of the contract logic (proxy), whereas the transaction sender will keep the ownership of the
data. Thus the Factory owner is responsible for the code. It is possible to transfer the proxy
to another account.

In any case, every Organization can have many *associated keys*. An *associated key* is an Ethereum address
registered in the Organization thatcan operate on behalf of the organization. That means
that for example, the associated key can **sign messages on behalf** of the Organization. This
is handy when providing guarantees or proving data integrity.

### Content consumers

When a consumer wants to participate, they have to do the following:

1. Locate Winding Tree Entrypoint address
1. Locate the appropriate Segment Directory address
1. Call `get*` on the Segment Directory.
1. Call `getOrgJsonUri` on every non-zero address returned as an instance of `OrganizationInterface` and crawl the off-chain data
for more information.

If a signed message occurs somewhere in the platform, a content consumer might want to decide
if it was signed by an account associated with the declared Organization. That's when they would 
first verify the signature and obtain an address of the signer. In the next step, they have to verify
that the actual signer is registered as an *associated key* with the Organization by checking its smart contract.

## Requirements

Node 10 is required for running the tests and contract compilation.

## Installation

```sh
npm install @windingtree/wt-contracts
```

```js
import Organization from '@windingtree/wt-contracts/build/contracts/Organization.json';
// or
import { Organization, AbstractSegmentDirectory } from '@windingtree/wt-contracts';
```

## Development

```sh
git clone https://github.com/windingtree/wt-contracts
nvm install
npm install
npm test
```

You can run a specific test with `npm test -- test/segment-directory.js`
or you can generate a coverage report with `npm run coverage`.

**Warning:** We are **not** using the `zos.json` in tests, rather `zos.test.json`. If you are
getting the `Cannot set a proxy implementation to a non-contract address` error, its probably
because of that.

### Flattener

A flattener script is also available. `npm run flattener` command
will create a flattened version without imports - one file per contract.
This is needed if you plan to use tools like [etherscan verifier](https://etherscan.io/verifyContract)
or [securify.ch](https://securify.ch/).

## Deployment

We are using the upgradeability proxy from [zos](https://docs.zeppelinos.org/)
and the deployment pipeline is using their system as well. You can read more
about the [publishing process](https://docs.zeppelinos.org/docs/deploying) and
[upgrading](https://docs.zeppelinos.org/docs/upgrading.html) in `zos`
documentation.

In order to interact with "real" networks such as `mainnet`, `ropsten` or others,
you need to setup a `keys.json` file used by [truffle](https://truffleframework.com/)
that does the heavy lifting for zos.

```json
{
  "mnemonic": "<SEED_PHRASE>",
  "infura_projectid": "<PROJECT_ID>"
}
```

### Upgradeability FAQ

**What does upgradeability mean?**

We can update the logic of Entrypoint, Segment Directory or Organization while keeping their
public address the same and *without touching any data*.

**Can you change the Organization data structure?**

The Organization Factory owner can, yes. As long as we adhere to
[zos recommendations](https://docs.zeppelinos.org/docs/writing_contracts.html#modifying-your-contracts),
it should be safe. The same applies for Segment Directory, Entrypoint and Factory.

**Can I switch to the new Organization version?**

If you created your Organization via Organization Factory, no. The Organization Factory
owner has to do that for you. If you deployed the (upgradeable) Organization yourself or reclaimed the
proxy ownership from Factory owner, you can do it yourself. If you used a non-upgradeable
smart contract implementation, then no.

**Why do I keep getting "revert Cannot call fallback function from the proxy admin" when interacting with Organization?**

This is a documented behaviour of [zos upgradeability](https://docs.zeppelinos.org/docs/faq.html#why-are-my-getting-the-error-cannot-call-fallback-function-from-the-proxy-admin).
You need to call the proxied Organization contract from
a different account than is the proxy owner.

**What happens when you upgrade the Directory?**

The Directory address stays the same, the client software has to
interact with the Directory only with the updated ABI which is distributed
via NPM (under the new version number). No data is lost.

**How do I work with different organization versions on the client?**
That should be possible by using an ABI of `OrganizationInterface` on the client side.


### Local testing

You don't need `keys.json` file for local testing of deployment and interaction
with the contracts.

1. Start a local Ethereum network.
    ```bash
    > npm run dev-net
    ```
2. Start a zos session.
    ```bash
    > ./node_modules/.bin/zos session --network development --from 0x87265a62c60247f862b9149423061b36b460f4BB --expires 3600
    ```
3. Deploy your contracts. This only uploads the logic, the contracts are not meant to be directly
interacted with.
    ```bash
    > ./node_modules/.bin/zos push --network development
    ```
4. Create the proxy instances of deployed contracts you can interact with. The `args`
attribute is passed to the initialize function that sets the `owner` of the Index (it
can be an address of a multisig), segment name, actual instance of
[Lif token](https://github.com/windingtree/lif-token) and a `zos app` address. The zos app
address (`0x988..` example below might differ). You don't need Lif token to play with this locally.
    ```bash
    > ./node_modules/.bin/zos create OrganizationFactory --network development --init initialize --args 0x87265a62c60247f862b9149423061b36b460f4BB,0x988f24d8356bf7e3D4645BA34068a5723BF3ec6B
    > ./node_modules/.bin/zos create SegmentDirectory --network development --init initialize --args 0x87265a62c60247f862b9149423061b36b460f4BB,hotels,0xB6e225194a1C892770c43D4B529841C99b3DA1d7
    ```
These commands will return a network address where you can actually interact with the contracts.
For a quick test, you can use the truffle console.
```bash
> ./node_modules/.bin/truffle console --network development
truffle(development)> factory = await OrganizationFactory.at('0x...address returned by zos create command')
truffle(development)> factory.create('https://windingtree.com')
truffle(development)> factory.getCreatedOrganizations()
truffle(development)> directory = await SegmentDirectory.at('0x...address returned by zos create command')
truffle(development)> directory.getOrganizations()
truffle(development)> directory.add('0x...address returned by the factory')
truffle(development)> directory.getOrganizations()
[ '0x0000000000000000000000000000000000000000',
  '0x4D377b0a8fa386FA118B09947eEE2B1f7f126C76' ]
```
To interact with the created Organization contract, you need to run truffle console under an account that
is not the owner of the `OrganizationFactory` (0x87265a62c60247f862b9149423061b36b460f4BB in this case).
