const { TestHelper } = require('@openzeppelin/cli');
const { Contracts, ZWeb3 } = require('@openzeppelin/upgrades');

const { assertRevert, assertEvent } = require('./helpers/assertions');
const orgIdSetup = require('./helpers/orgid');
const {
    zeroAddress
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

const Directory = Contracts.getFromLocal('Directory');
const DirectoryInterface = artifacts.require('DirectoryInterface');
const DirectoryUpgradeability = Contracts.getFromLocal('DirectoryUpgradeability');
const FakeOrgId = Contracts.getFromLocal('FakeOrgId');

require('chai').should();

contract('Directory', accounts => {
    
    const orgIdOwner = accounts[1];
    const dirOwner = accounts[2];
    const nonOwner = accounts[3];

    const segmentName = 'hotels';
    let project;
    let dir;
    let orgId;
    
    beforeEach(async () => {
        orgId = await orgIdSetup(orgIdOwner);
        project = await TestHelper({
            from: dirOwner
        });
        dir = await project.createProxy(Directory, {
            initMethod: 'initialize',
            initArgs: [
                dirOwner,
                segmentName,
                orgId.address
            ]
        });
    });

    describe('Upgradeability behaviour', () => {

        it('should upgrade proxy and reveal a new function and interface', async () => {
            dir = await project.upgradeProxy(
                dir.address,
                DirectoryUpgradeability,
                {
                    initMethod: 'initialize',
                    initArgs: []
                }
            );
            await dir.methods['setupNewStorage(uint256)']('100').send({
                from: dirOwner
            });
            (await dir.methods['newFunction()']().call()).should.equal('100');
            (
                await dir
                    .methods['supportsInterface(bytes4)']('0x1b28d63e')
                    .call()
            ).should.be.true;
        });

        describe('#initialize(address,string,address)', () => {

            it('should fail if zero address been provided as owner', async () => {
                await assertRevert(
                    project.createProxy(Directory, {
                        initMethod: 'initialize',
                        initArgs: [
                            zeroAddress,
                            segmentName,
                            orgId.address
                        ]
                    })
                );
            });

            it('should fail if empty segment name been provided', async () => {
                await assertRevert(
                    project.createProxy(Directory, {
                        initMethod: 'initialize',
                        initArgs: [
                            dirOwner,
                            '',
                            orgId.address
                        ]
                    })
                );
            });

            it('should fail if zero address provided as orgId', async () => {
                await assertRevert(
                    project.createProxy(Directory, {
                        initMethod: 'initialize',
                        initArgs: [
                            dirOwner,
                            segmentName,
                            zeroAddress
                        ]
                    })
                );
            });

            it('should fail if provided OrgId has not supperted standard ORG.ID interface', async () => {
                const fakeOrgId = await FakeOrgId.new();
                await assertRevert(
                    project.createProxy(Directory, {
                        initMethod: 'initialize',
                        initArgs: [
                            dirOwner,
                            segmentName,
                            fakeOrgId.address
                        ]
                    })
                );
            });
        });
    });

    describe('Ownable behaviour', () => {

        describe('#transferOwnership(address)', () => {

            it('should fail if called by not an owner', async () => {
                await assertRevert(
                    dir
                        .methods['transferOwnership(address)'](nonOwner)
                        .send({
                            from: nonOwner
                        }),
                    'Ownable: caller is not the owner'
                );
            });
    
            it('should fail if new owner has zero address', async () => {
                await assertRevert(
                    dir
                        .methods['transferOwnership(address)'](zeroAddress)
                        .send({
                            from: dirOwner
                        }),
                    'Ownable: new owner is the zero address'
                );
            });

            it('should transfer contract ownership', async () => {
                const result = await dir
                    .methods['transferOwnership(address)'](nonOwner)
                    .send({
                        from: dirOwner
                    });
                await assertEvent(result, 'OwnershipTransferred', [
                    [
                        'previousOwner',
                        p => (p).should.equal(dirOwner)
                    ],
                    [
                        'newOwner',
                        p => (p).should.equal(nonOwner)
                    ],
                ]);
            });
        });

        describe('#owner()', () => {

            it('should return contract owner', async () => {
                (await dir.methods['owner()']().call())
                    .should.equal(dirOwner);
            });
        });
    });

    describe('ERC165 interfaces', () => {

        it('should support IERC165 interface', async () => {
            (
                await dir
                    .methods['supportsInterface(bytes4)']('0x01ffc9a7')
                    .call()
            ).should.be.true;
        });

        it('should support ownable interface', async () => {
            (
                await dir
                    .methods['supportsInterface(bytes4)']('0x7f5828d0')
                    .call()
            ).should.be.true;
        });

        it('should support directory interface', async () => {
            (
                await dir
                    .methods['supportsInterface(bytes4)']('0xcc915ab7')
                    .call()
            ).should.be.true;
        });
    });

    describe('Directory methods', () => {

        describe('#setSegment(string)', () => {

            it('should fail if called not by an owner', async () => {
                await assertRevert(
                    dir
                        .methods['setSegment(string)']('airlines')
                        .send({ from: nonOwner }),
                    'Ownable: caller is not the owner'
                );
            });

            it('should fail if empty segment name has been provided', async () => {
                await assertRevert(
                    dir
                        .methods['setSegment(string)']('')
                        .send({ from: dirOwner }),
                    'Directory: Segment cannot be empty'
                );
            });

            it('should set a segment', async () => {
                const newSegment = 'airlines';
                const result = await dir
                    .methods['setSegment(string)'](newSegment)
                    .send({ from: dirOwner });
                assertEvent(result, 'SegmentChanged', [
                    [
                        'previousSegment',
                        p => (p).should.equal(segmentName)
                    ],
                    [
                        'newSegment',
                        p => (p).should.equal(newSegment)
                    ]
                ]);
                (
                    await dir.methods['getSegment()']().call()
                ).should.equal(newSegment);
            });
        });

        describe('#getSegment()', () => {
            
            it('should return a segment name', async () => {
                (
                    await dir.methods['getSegment()']().call()
                ).should.equal(segmentName);
            });
        });

        describe.skip('#add(bytes32)', () => {});

        describe.skip('#remove(bytes32)', () => {});

        describe.skip('#getOrganizations()', () => {});
    });
});
