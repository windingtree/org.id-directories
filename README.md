[![Build Status](https://travis-ci.org/windingtree/org.id-directories.svg?branch=master)](https://travis-ci.org/windingtree/org.id-directories)
[![Coverage Status](https://coveralls.io/repos/github/windingtree/org.id-directories/badge.svg?branch=master)](https://coveralls.io/github/windingtree/org.id-directories?branch=master&v=2.0)

# Directory and DirectoryIndex Smart Contracts

Smart contracts of the Winding Tree ORG.ID protocol

## Initial setup

```bash
npm i
```

## Tests

```bash
npm run test
npm run test ./<path_to_test_file>.js
```

## Tests coverage

```bash
npm run coverage
```

## Linting

```bash
npm run lint

```

## Generated docs
- [Directory](./docs/Directory.md)
- [DirectoryIndex](./docs/DirectoryIndex.md)

## Contracts ABIs

Install the package

```bash
$ npm i @windingtree/org.id-directories
```

Import ABIs in the your JavaScript code

```javascript
const {
  DirectoryContract,
  DirectoryIndexContract,
  DirectoryInterfaceContract,
  DirectoryIndexInterfaceContract
} = require('@windingtree/org.id-directories');
```

## Directory deployment

All deployments, upgrades, transactions and calls can be handled using [@windingtree/smart-contracts-tools](https://github.com/windingtree/smart-contracts-tools):

```bash
$ npx tools --network ropsten cmd=deploy name=Directory from=0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959 initMethod=initialize initArgs=0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959,hotel,0xc8fD300bE7e4613bCa573ad820a6F1f0b915CfcA
```

The result will look like:

```bash
Deployment of the contract:  Directory
Version:  0.11.1
Owner address:  0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959
Initializing method:  initialize
Initializing arguments:  [ '0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959',
  'hotel',
  '0xc8fD300bE7e4613bCa573ad820a6F1f0b915CfcA' ]
Contract deployed at address:  0xF1Dd1412189Ed1757200B08C3293f7a8f08DCdac
```

Auto-generated deployment configuration will be saved on the `./openzeppelin` repository folder and will look like:

```json
{
  "version": "0.11.1",
  "contract": {
    "name": "Directory",
    "implementation": "0xAFaEbFC3785416E9259B2a6F0ab62B07F21f5470",
    "proxy": "0xF1Dd1412189Ed1757200B08C3293f7a8f08DCdac"
  },
  "owner": "0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959",
  "proxyAdmin": "0x418547B504D4e2c64dE6fCd37BeD1Fd740416558",
  "blockNumber": 7461013
}
```

The filename of the configuration file is formed according to mask:
`./<NETWORK_NAME>-<CONTRACT_NAME>.json`

`development` network has `private` name, so the name of file will be `private-Directory.json`

## DirectoryIndex deployment

```bash
$ orgid-tools --network ropsten cmd=deploy name=DirectoryIndex from=0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959 initMethod=initialize initArgs=0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959
```

The result will look like:

```bash
Deployment of the contract:  DirectoryIndex
Version:  0.11.1
Owner address:  0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959
Initializing method:  initialize
Initializing arguments:  [ '0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959' ]
Contract deployed at address:  0xeD0f263e005e306de3F8Af9d74D1B3F8edEb33A3
```

Auto-generated deployment configuration will be saved in the file `./openzeppelin/private-DirectoryIndex.json`

```json
{
  "version": "0.11.1",
  "contract": {
    "name": "DirectoryIndex",
    "implementation": "0x3662823F4a5bb045365f3d7424Ea8c8B5Cf7Ab49",
    "proxy": "0xeD0f263e005e306de3F8Af9d74D1B3F8edEb33A3"
  },
  "owner": "0xA0B74BFE28223c9e08d6DBFa74B5bf4Da763f959",
  "proxyAdmin": "0x7702e5E832d772fDD38C5d01B47651e4DfA2bfa2",
  "blockNumber": 7461027
}
```