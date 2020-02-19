const { TestHelper } = require('@openzeppelin/cli');
const { Contracts, ZWeb3 } = require('@openzeppelin/upgrades');

const { assertRevert, assertEvent } = require('./helpers/assertions');
const {
    orgIdSetup,
    createOrganization,
    createSubsidiary,
    toggleOrganization,
    generateId
} = require('./helpers/orgid');
const {
    zeroAddress,
    zeroBytes
} = require('./helpers/constants');

let gasLimit = 8000000; // Like actual to the Ropsten

if (process.env.SOLIDITY_COVERAGE) {
    gasLimit = 0xfffffffffff;
    Contracts.setLocalBuildDir('./.coverage_artifacts/contracts');
}

// workaround for https://github.com/zeppelinos/zos/issues/704
Contracts.setArtifactsDefaults({
    gas: gasLimit,
});

ZWeb3.initialize(web3.currentProvider);

const DirectoryIndex = Contracts.getFromLocal('DirectoryIndex');
const DirectoryIndexUpgradeability = Contracts.getFromLocal('DirectoryIndexUpgradeability');

require('chai').should();

contract('DirectoryIndex', accounts => {

    const dirOwner = accounts[2];

    let project;
    let dir;

    beforeEach(async () => {
        project = await TestHelper({
            from: dirOwner
        });
        dir = await project.createProxy(DirectoryIndex, {
            initMethod: 'initialize',
            initArgs: [
                dirOwner
            ]
        });
    });
    
    describe('Upgradeability behaviour', () => {

        it('should upgrade proxy and reveal a new function and interface', async () => {
            dir = await project.upgradeProxy(
                dir.address,
                DirectoryIndexUpgradeability
            );
            await dir.methods['setupNewStorage(uint256)']('100').send({
                from: dirOwner
            });
            (await dir.methods['newFunction()']().call()).should.equal('100');
        });

        describe('#initialize(address)', () => {

            it('should fail if zero address been provided as owner', async () => {
                await assertRevert(
                    project.createProxy(DirectoryIndex, {
                        initMethod: 'initialize',
                        initArgs: [
                            zeroAddress
                        ]
                    })
                );
            });
        });
    });

    describe('Ownable behaviour', () => {});

    describe('DirectoryIndex methods', () => {});
});
