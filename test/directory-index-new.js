const { TestHelper } = require('@openzeppelin/cli');
const { Contracts, ZWeb3 } = require('@openzeppelin/upgrades');

const { assertRevert, assertEvent } = require('./helpers/assertions');
const { orgIdSetup } = require('./helpers/orgid');

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
const Directory = Contracts.getFromLocal('Directory');
const ArbitrableDirectory = Contracts.getFromLocal('ArbitrableDirectory');
const FakeDirectory = Contracts.getFromLocal('FakeDirectory');
const Arbitrator = artifacts.require('EnhancedAppealableArbitrator');
const Lif = artifacts.require('LifTest');

require('chai').should();

contract('DirectoryIndex: With ArbitrableDirectory support', accounts => {
    let project;
    let index;
    let orgId;
    let lif;
    let arbitrator;

    const indexOwner = accounts[1];
    const orgIdOwner = accounts[2];
    const dirOwner = accounts[3];
    const governor = accounts[4];
    const disputeOwner = accounts[5];

    const arbitrationCost = 1000;
    const arbitratorExtraData = '0x85';
    const appealTimeOut = 180;
    const metaEvidence = 'MetaEvidence.json';
    const requesterDeposit = 500;
    const challengeBaseDeposit = 10000;
    const executionTimeout = 120;
    const responseTimeout = 150;
    const withdrawTimeout = 60;
    const sharedStakeMultiplier = 5000;
    const winnerStakeMultiplier = 2000;
    const loserStakeMultiplier = 8000;

    before(async () => {
        project = await TestHelper({
            from: indexOwner
        });
        index = await project.createProxy(DirectoryIndex, {
            initMethod: 'initialize',
            initArgs: [
                indexOwner
            ]
        });
        orgId = await orgIdSetup(orgIdOwner);
        lif = await Lif.new('Lif', 'LIF', 18, '1000000', {
            from: orgIdOwner
        });
        arbitrator = await Arbitrator.new(
            arbitrationCost,
            governor,
            arbitratorExtraData,
            appealTimeOut,
            {
                from: governor
            }
        );
        await arbitrator.changeArbitrator(arbitrator.address, {
            from: governor
        });
        await arbitrator.createDispute(3, arbitratorExtraData, {
            from: disputeOwner,
            value: arbitrationCost
        });
    });

    describe('#addSegment(address)', () => {

        it('should fail if fake directory has been provided', async () => {
            const dir = await project.createProxy(FakeDirectory, {
                initMethod: 'initialize',
                initArgs: []
            });
            await assertRevert(
                index.methods['addSegment(address)'](dir.address).send({
                    from: indexOwner
                }),
                'DirectoryIndex: Segment has to support directory interface'
            );
        });

        it('should add Directory instance', async () => {
            const dir = await project.createProxy(Directory, {
                initMethod: 'initialize',
                initArgs: [
                    dirOwner,
                    'hotels',
                    orgId.address
                ]
            });
            const result = await index.methods['addSegment(address)'](dir.address).send({
                from: indexOwner
            });
            await assertEvent(result, 'SegmentAdded', [
                [
                    'segment',
                    p => (p).should.equal(dir.address)
                ],
                [
                    'index',
                    p => (Number(p)).should.not.equal(0)
                ],
            ]);
        });

        it('should add ArbitrableDirectory instance', async () => {
            const dir = await project.createProxy(ArbitrableDirectory, {
                initMethod: 'initialize',
                initArgs: [
                    governor,
                    'hotels',
                    orgId.address,
                    lif.address,
                    arbitrator.address,
                    arbitratorExtraData,
                    metaEvidence,
                    requesterDeposit,
                    challengeBaseDeposit,
                    executionTimeout,
                    responseTimeout,
                    withdrawTimeout,
                    [
                        sharedStakeMultiplier,
                        winnerStakeMultiplier,
                        loserStakeMultiplier
                    ]
                ]
            });
            const result = await index.methods['addSegment(address)'](dir.address).send({
                from: indexOwner
            });
            await assertEvent(result, 'SegmentAdded', [
                [
                    'segment',
                    p => (p).should.equal(dir.address)
                ],
                [
                    'index',
                    p => (Number(p)).should.not.equal(0)
                ],
            ]);
        });
    });
});
