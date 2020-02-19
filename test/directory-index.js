const { TestHelper } = require('@openzeppelin/cli');
const { Contracts, ZWeb3 } = require('@openzeppelin/upgrades');

const { assertRevert, assertEvent } = require('./helpers/assertions');
const { createDirectory } = require('./helpers/directory');
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
const FakeDirectory = Contracts.getFromLocal('FakeDirectory');

require('chai').should();

contract('DirectoryIndex', accounts => {

    const orgIdOwner = accounts[1];
    const dirOwner = accounts[2];
    const segmentOwner = accounts[3];
    const nonOwner = accounts[4];

    const segmentName = 'hotels';
    let project;
    let dir;
    let segment;

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
        const segmentSetup = await createDirectory(
            orgIdOwner,
            segmentOwner,
            segmentName
        );
        segment = segmentSetup.directory;
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

    describe('DirectoryIndex methods', () => {

        describe('#addSegment(address)', () => {

            it('should fail if called by not an owner', async () => {
                await assertRevert(
                    dir
                        .methods['addSegment(address)'](segment.address)
                        .send({ from: nonOwner }),
                    'Ownable: caller is not the owner'
                );
            });

            it('should fail is zero address provided as segment address', async () => {
                await assertRevert(
                    dir
                        .methods['addSegment(address)'](zeroAddress)
                        .send({ from: dirOwner }),
                    'DirectoryIndex: Invalid segment address'
                );
            });

            it('should fail if segment not supported directory interface', async () => {
                const fakeDirectory = await FakeDirectory.new();
                await assertRevert(
                    dir
                        .methods['addSegment(address)'](fakeDirectory.address)
                        .send({ from: dirOwner }),
                    'DirectoryIndex: Segment has to support directory interface'
                );
            });

            it('should add new segment address', async () => {
                const result = await dir
                    .methods['addSegment(address)'](segment.address)
                    .send({ from: dirOwner });
                assertEvent(result, 'SegmentAdded', [
                    [
                        'segment',
                        p => (p).should.equal(segment.address)
                    ],
                    [
                        'index',
                        p => (Number(p)).should.not.equal(0)
                    ]
                ]);
            });
        });

        describe('#removeSegment(address)', () => {});

        describe('#getSegment(address)', () => {});

        describe('#getSegments(address)', () => {});
    });
});
