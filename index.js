
const ArbitrableDirectoryContract = require('./build/contracts/ArbitrableDirectory.json');
const DirectoryContract = require('./build/contracts/Directory.json');
const DirectoryIndexContract = require('./build/contracts/DirectoryIndex.json');
const DirectoryIndexInterfaceContract = require('./build/contracts/DirectoryIndexInterface.json');
const DirectoryInterfaceContract = require('./build/contracts/DirectoryInterface.json');
const ropstenDirectoryIndexConfig = require('./.openzeppelin/ropsten-DirectoryIndex.json');

module.exports = {
    ArbitrableDirectoryContract: ArbitrableDirectoryContract,
    DirectoryContract: DirectoryContract,
    DirectoryIndexContract: DirectoryIndexContract,
    DirectoryIndexInterfaceContract: DirectoryIndexInterfaceContract,
    DirectoryInterfaceContract: DirectoryInterfaceContract,
    addresses: {
        DirectoryIndex: {
            ropsten: ropstenDirectoryIndexConfig.contract.proxy
        }
    }
};

