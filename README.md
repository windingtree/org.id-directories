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
[Directory](./docs/Directory.md)
[DirectoryIndex](./docs/DirectoryIndex.md)

## Directory deployment

All deployments, upgrades, transactions and calls can be hadled using our [command line tools](./management/tools/README.md): 

```bash
$ ./management/tools/index.js --network development cmd=contract name=Directory initMethod=initialize initArgs=0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1,hotels,[ORGID_ADDRESS] from=0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1 
```

The result will look like:

```bash
WindingTree Command Line Interface  
Version:  0.10.0
Contract name:  Directory
Actual version:  0.10.0
Last known version:  0.10.0
App address:  0xDb56f2e9369E0D7bD191099125a3f6C370F8ed15
Proxy admin:  0x5f8e26fAcC23FA4cbd87b8d9Dbbd33D5047abDE1
Contract implementation:  0x21a59654176f2689d12E828B77a783072CD26680
New deployment  
Contract proxy:  0x4bf749ec68270027C5910220CEAB30Cc284c7BA2
```

Auto-generated deployment configuration will be saved on the `./openzeppelin` repository folder and will look like:

```json
"version": "0.10.0",
  "contract": {
    "name": "Directory",
    "implementation": "0x21a59654176f2689d12E828B77a783072CD26680",
    "proxy": "0x4bf749ec68270027C5910220CEAB30Cc284c7BA2"
  },
  "owner": "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
  "app": "0xDb56f2e9369E0D7bD191099125a3f6C370F8ed15",
  "proxyAdmin": "0x5f8e26fAcC23FA4cbd87b8d9Dbbd33D5047abDE1",
  "implementationDirectory": "0x6eD79Aa1c71FD7BdBC515EfdA3Bd4e26394435cC",
  "package": "0xA94B7f0465E98609391C623d0560C5720a3f2D33",
  "blockNumber": 26
```

The filename of the configuration file is formed according to mask:   
`./[NETWORK_NAME]-[CONTRACT_NAME].json`   

`development` network has `private` name, so the name of file will be `private-Directory.json`

## DirectoryIndex deployment

```bash
$ ./management/tools/index.js --network development cmd=contract name=DirectoryIndex initMethod=initialize initArgs=0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1 from=0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1 
```

The result will look like:

```bash
WindingTree Command Line Interface  
Version:  0.10.0
Contract name:  DirectoryIndex
Actual version:  0.10.0
Last known version:  0.10.0
App address:  0xaD888d0Ade988EbEe74B8D4F39BF29a8d0fe8A8D
Proxy admin:  0xA586074FA4Fe3E546A132a16238abe37951D41fE
Contract implementation:  0x2D8BE6BF0baA74e0A907016679CaE9190e80dD0A
New deployment  
Contract proxy:  0x5b9b42d6e4B2e4Bf8d42Eba32D46918e10899B66
```

Auto-generated deployment configuration will be saved in the file `./openzeppelin/private-DirectoryIndex.json`

```json
{
  "version": "0.10.0",
  "contract": {
    "name": "DirectoryIndex",
    "implementation": "0x2D8BE6BF0baA74e0A907016679CaE9190e80dD0A",
    "proxy": "0x5b9b42d6e4B2e4Bf8d42Eba32D46918e10899B66"
  },
  "owner": "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
  "app": "0xaD888d0Ade988EbEe74B8D4F39BF29a8d0fe8A8D",
  "proxyAdmin": "0xA586074FA4Fe3E546A132a16238abe37951D41fE",
  "implementationDirectory": "0x5017A545b09ab9a30499DE7F431DF0855bCb7275",
  "package": "0x7C728214be9A0049e6a86f2137ec61030D0AA964",
  "blockNumber": 35
}
```