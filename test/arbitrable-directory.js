/* eslint-disable no-undef */ // Avoid the linter considering truffle elements as undef.
const { BN, expectRevert, time } = require('openzeppelin-test-helpers');
const { soliditySha3 } = require('web3-utils');

const ArbitrableDirectory = artifacts.require('ArbitrableDirectory');
const Arbitrator = artifacts.require('EnhancedAppealableArbitrator');
const Lif = artifacts.require('LifTest');
const OrgID = artifacts.require('OrgId');

contract('ArbitrableDirectory', function (accounts) {
    const governor = accounts[0];
    const requester = accounts[1];
    const challenger = accounts[2];
    const other = accounts[3];
    const arbitratorExtraData = '0x85';
    const arbitrationCost = 1000;
    const appealTimeOut = 180;
    const tokenSupply = 100000;

    const segment = 'TEST_SEGMENT';
    const requesterDeposit = 500;
    const challengeBaseDeposit = 10000;
    const executionTimeout = 120;
    const responseTimeout = 150;
    const withdrawTimeout = 60;
    const sharedStakeMultiplier = 5000;
    const winnerStakeMultiplier = 2000;
    const loserStakeMultiplier = 8000;
    const metaEvidence = 'MetaEvidence.json';

    const PARTY = {
        NONE: 0,
        REQUESTER: 1,
        CHALLENGER: 2
    };

    let arbitrator;
    let lif;
    let orgId;
    let createTx;
    let ID; // bytes32 ID of the organization.
    let challengeTotalCost; // The cost to accept the challenge is the same value.
    let MULTIPLIER_DIVISOR;
    beforeEach('initialize the contract', async function () {
        arbitrator = await Arbitrator.new(
            arbitrationCost,
            governor,
            arbitratorExtraData,
            appealTimeOut,
            { from: governor }
        );

        await arbitrator.changeArbitrator(arbitrator.address);
        await arbitrator.createDispute(3, arbitratorExtraData, {
            from: other,
            value: arbitrationCost
        }); // Create a dispute so the index in tests will not be a default value.

        lif = await Lif.new('Lif', 'LIF', 18, tokenSupply, { from: requester });

        orgId = await OrgID.new(); // A contract that represents an OrgId registry.
        createTx = await orgId.createOrganization(
            soliditySha3('salt'),
            soliditySha3('hash'),
            '',
            '',
            '',
            { from: requester }
        );
        ID = createTx.logs[0].args.orgId; // The id of the organization can be obtained from the event.

        aD = await ArbitrableDirectory.new();

        await aD.initialize(
            governor,
            segment,
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
            [sharedStakeMultiplier, winnerStakeMultiplier, loserStakeMultiplier],
            { from: governor }
        );

        MULTIPLIER_DIVISOR = (await aD.MULTIPLIER_DIVISOR()).toNumber();
        await lif.approve(aD.address, 10000, {
            from: requester
        });

        challengeTotalCost = arbitrationCost + challengeBaseDeposit; // 11000
    });

    it('Should set the correct values in initializer', async () => {
        assert.equal(await aD.governor(), governor);
        assert.equal(await aD.getSegment(), segment);
        assert.equal(await aD.orgId(), orgId.address);
        assert.equal(await aD.lif(), lif.address);
        assert.equal(await aD.arbitrator(), arbitrator.address);
        assert.equal(await aD.arbitratorExtraData(), arbitratorExtraData);
        assert.equal(await aD.RULING_OPTIONS(), '2');
        assert.equal(await aD.requesterDeposit(), requesterDeposit);
        assert.equal(await aD.challengeBaseDeposit(), challengeBaseDeposit);
        assert.equal(await aD.executionTimeout(), executionTimeout);
        assert.equal(await aD.responseTimeout(), responseTimeout);
        assert.equal(await aD.withdrawTimeout(), withdrawTimeout);
        assert.equal(await aD.sharedStakeMultiplier(), sharedStakeMultiplier);
        assert.equal(await aD.winnerStakeMultiplier(), winnerStakeMultiplier);
        assert.equal(await aD.loserStakeMultiplier(), loserStakeMultiplier);
        const emptyOrg = await aD.registeredOrganizations(0);
        assert.equal(emptyOrg, 0x0, 'Unexpected org value with 0 index');
    });

    // it('Should return the directory info', async () => {
    //     const info = await aD.getInfo();
    //     assert.equal(info.governor, governor);
    //     assert.equal(info.getSegment, segment);
    //     assert.equal(info.orgId, orgId.address);
    //     assert.equal(info.lif, lif.address);
    //     assert.equal(info.arbitrator, arbitrator.address);
    //     assert.equal(info.arbitratorExtraData, arbitratorExtraData);
    //     assert.equal(info.requesterDeposit, requesterDeposit);
    //     assert.equal(info.challengeBaseDeposit, challengeBaseDeposit);
    //     assert.equal(info.executionTimeout, executionTimeout);
    //     assert.equal(info.responseTimeout, responseTimeout);
    //     assert.equal(info.withdrawTimeout, withdrawTimeout);
    //     assert.equal(info.sharedStakeMultiplier, sharedStakeMultiplier);
    //     assert.equal(info.winnerStakeMultiplier, winnerStakeMultiplier);
    //     assert.equal(info.loserStakeMultiplier, loserStakeMultiplier);
    // });

    it('Should set the correct values when making a new request', async () => {
    // Check the requires first.
        await expectRevert(
            aD.requestToAdd(soliditySha3('FakeOrg'), { from: requester }),
            'Directory: Organization not found.'
        );
        await expectRevert(
            aD.requestToAdd(ID, { from: other }),
            'Directory: Only organization owner or director can add the organization.'
        );

        await orgId.toggleActiveState(ID, { from: requester });
        await expectRevert(
            aD.requestToAdd(ID, { from: requester }),
            'Directory: Only enabled organizations can be added.'
        );
        await orgId.toggleActiveState(ID, { from: requester });

        await aD.requestToAdd(ID, { from: requester });

        const requestedCount = await aD.getRequestedOrganizationsCount(0, 0);
        assert.equal(requestedCount, 1, 'Wrong requested organization count');

        const requestedOrgs = await aD.getRequestedOrganizations(0, 0);
        assert.equal(requestedOrgs[0], ID, 'Requested organization organization not appeared in the organizations list');

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[0], ID, 'The ID is not set up properly');
        assert.equal(orgData[1].toNumber(), 1, 'The status is not set up properly');
        assert.equal(orgData[2], requester, 'The requester is not set up properly');
        assert.equal(
            orgData[4].toNumber(),
            500,
            'The lif stake is not set up properly'
        );
        assert.equal(
            orgData[5].toNumber(),
            0,
            'The withdrawal request time should stay default'
        );

        assert.equal(
            (await lif.balanceOf(requester)).toNumber(),
            99500,
            'Incorrect token balance of the requester'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            500,
            'Incorrect token balance of the contract'
        );

        await expectRevert(
            aD.requestToAdd(ID, { from: requester }),
            'Directory: The organization must be either registered or registering.'
        );
    });

    it('The director should be able to make a request', async () => {
        await orgId.transferDirectorship(ID, other, { from: requester });
        // Check that the director can't do the request if he is not confirmed.
        await expectRevert(
            aD.requestToAdd(ID, { from: other }),
            'Directory: Only organization owner or director can add the organization.'
        );
        await orgId.acceptDirectorship(ID, { from: other });

        await lif.transfer(other, 10000, {
            from: requester
        });
        await lif.approve(aD.address, 10000, {
            from: other
        });

        await aD.requestToAdd(ID, { from: other });

        const orgData = await aD.organizationData(ID);

        assert.equal(orgData[2], other, 'The requester is not set up properly');

        assert.equal(
            (await lif.balanceOf(other)).toNumber(),
            9500,
            'Incorrect token balance of the requester'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            500,
            'Incorrect token balance of the contract'
        );
    });

    it('Should set the correct values when challenging a request and fire the event', async () => {
        await aD.requestToAdd(ID, { from: requester });
        // Check that it's not possible to challenge the organization that wasn't added.
        await expectRevert(
            aD.challengeOrganization(soliditySha3('fakeOrg'), 'Evidence.json', {
                from: challenger,
                value: challengeTotalCost
            }),
            'Directory: The organization should be either registered or registering.'
        );

        await expectRevert(
            aD.challengeOrganization(ID, 'Evidence.json', {
                from: challenger,
                value: challengeTotalCost - 1
            }),
            'Directory: You must fully fund your side.'
        );

        txChallenge = await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        const orgData = await aD.organizationData(ID);
        assert.equal(
            orgData[1].toNumber(),
            3,
            'The organization should have status Challenged'
        );

        // Check the challenge info.
        const challengeData = await aD.getChallengeInfo(ID, 0);
        assert.equal(
            challengeData[3],
            challenger,
            'The challenger is not set up properly'
        );
        assert.equal(
            challengeData[4].toNumber(),
            1,
            'The total number of rounds is incorrect'
        );
        assert.equal(
            challengeData[6],
            arbitrator.address,
            'The arbitrator is not set up properly'
        );
        assert.equal(
            challengeData[7],
            0x85,
            'The extra data is not set up properly'
        );
        assert.equal(
            challengeData[8].toNumber(),
            0,
            'The metaevidence ID is not set up properly'
        );

        const nbChallenges = (await aD.getNumberOfChallenges(ID)).toNumber();
        assert.equal(
            nbChallenges,
            1,
            'Incorrect number of challenges for the organization'
        );

        // Check the OrganizationChallenged event.
        assert.equal(
            txChallenge.logs[0].event,
            'OrganizationChallenged',
            'The event OrganizationChallenged has not been created'
        );
        assert.equal(
            txChallenge.logs[0].args._organization,
            ID,
            'The event has wrong _organization'
        );
        assert.equal(
            txChallenge.logs[0].args._challenger,
            challenger,
            'The event has wrong _challenger'
        );
        assert.equal(
            txChallenge.logs[0].args._challenge,
            0,
            'The event has wrong _challenge Id'
        );

        // Check the Evidence event.
        const evidenceGroupID = parseInt(soliditySha3(ID, nbChallenges), 16);
        assert.equal(
            txChallenge.logs[1].event,
            'Evidence',
            'The event Evidence has not been created'
        );
        assert.equal(
            txChallenge.logs[1].args._arbitrator,
            arbitrator.address,
            'The event has wrong arbitrator'
        );
        assert.equal(
            txChallenge.logs[1].args._evidenceGroupID,
            evidenceGroupID,
            'The event has wrong evidenceGroup ID'
        );
        assert.equal(
            txChallenge.logs[1].args._party,
            challenger,
            'The event has wrong party'
        );
        assert.equal(
            txChallenge.logs[1].args._evidence,
            'Evidence.json',
            'The event has wrong evidence'
        );

        // Check the round.
        const round = await aD.getRoundInfo(ID, 0, 0);
        assert.equal(
            round[1][2].toNumber(),
            challengeTotalCost,
            'Challenger paidFees has not been registered correctly'
        );
        assert.equal(
            round[2][2],
            true,
            'Should register that challenger paid his fees'
        );
        assert.equal(
            round[3].toNumber(),
            challengeTotalCost,
            'FeeRewards has not been registered correctly after challenge'
        );

        // Check that it's not possible to challenge while the challenge is active.
        await expectRevert(
            aD.challengeOrganization(ID, 'Evidence.json', {
                from: challenger,
                value: challengeTotalCost
            }),
            'Directory: The organization should be either registered or registering.'
        );
    });

    it('Should set the correct values when accepting a challenge, fire the event and create a dispute', async () => {
        await aD.requestToAdd(ID, { from: requester });
        // The total cost to accept the challenge is equal to the cost of challenge.
        await expectRevert(
            aD.acceptChallenge(ID, 'Accept.json', {
                from: other,
                value: challengeTotalCost
            }),
            'Directory: The organization should have status Challenged.'
        );

        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await expectRevert(
            aD.acceptChallenge(ID, 'Accept.json', {
                from: other,
                value: challengeTotalCost - 1
            }),
            'Directory: You must fully fund your side.'
        );

        // Check that any address can accept the challenge on requester's behalf.
        txAccept = await aD.acceptChallenge(ID, 'Accept.json', {
            from: other,
            value: challengeTotalCost
        });

        const orgData = await aD.organizationData(ID);
        assert.equal(
            orgData[1].toNumber(),
            4,
            'The organization should have status Disputed'
        );
        const arbitratorDisputeIDToOrg = await aD.arbitratorDisputeIDToOrg(
            arbitrator.address,
            1
        );
        assert.equal(
            arbitratorDisputeIDToOrg,
            ID,
            'Incorrect arbitratorDisputeIDToOrg value'
        );

        // Check the challenge info.
        const challengeData = await aD.getChallengeInfo(ID, 0);
        assert.equal(challengeData[0], true, 'The challenge should be disputed');
        assert.equal(challengeData[1].toNumber(), 1, 'The dispute ID is incorrect');
        assert.equal(
            challengeData[4].toNumber(),
            2,
            'The number of rounds should increase'
        );

        // Check the round.
        const round = await aD.getRoundInfo(ID, 0, 0);
        assert.equal(
            round[1][1].toNumber(),
            challengeTotalCost,
            'Requester paidFees has not been registered correctly'
        );
        assert.equal(
            round[2][1],
            true,
            'Should register that requester paid his fees'
        );
        assert.equal(
            round[3].toNumber(),
            21000, // ChallengerTotalCost*2 + arbitrationCost = 10000*2 + 1000
            'FeeRewards has not been registered correctly after accepting the challenge'
        );

        // Check the event.
        const evidenceGroupID = parseInt(soliditySha3(ID, 1), 16);
        assert.equal(
            txAccept.logs[0].event,
            'Dispute',
            'The event Dispute has not been created'
        );
        assert.equal(
            txAccept.logs[0].args._arbitrator,
            arbitrator.address,
            'The event has wrong arbitrator'
        );
        assert.equal(
            txAccept.logs[0].args._disputeID.toNumber(),
            1,
            'The event has wrong dispute ID'
        );
        assert.equal(
            txAccept.logs[0].args._metaEvidenceID.toNumber(),
            0,
            'The event has wrong metaevidence ID'
        );
        assert.equal(
            txAccept.logs[0].args._evidenceGroupID,
            evidenceGroupID,
            'The event has wrong evidenceGroup ID'
        );

        assert.equal(
            txAccept.logs[1].event,
            'Evidence',
            'The event Evidence has not been created'
        );
        assert.equal(
            txAccept.logs[1].args._arbitrator,
            arbitrator.address,
            'The event has wrong arbitrator'
        );
        assert.equal(
            txAccept.logs[1].args._evidenceGroupID,
            evidenceGroupID,
            'The event has wrong evidenceGroup ID'
        );
        assert.equal(
            txAccept.logs[1].args._party,
            other,
            'The event has wrong party'
        );
        assert.equal(
            txAccept.logs[1].args._evidence,
            'Accept.json',
            'The event has wrong evidence'
        );

        // Check the dispute on arbitrator's side.
        const dispute = await arbitrator.disputes(1);
        assert.equal(dispute[0], aD.address, 'Arbitrable is not set up properly');
        assert.equal(
            dispute[1].toNumber(),
            2,
            'Number of choices is not set up properly'
        );
        assert.equal(
            dispute[2].toNumber(),
            arbitrationCost,
            'Arbitration cost is not set up properly'
        );

        // Check that can't accept twice.
        await expectRevert(
            aD.acceptChallenge(ID, 'Accept.json', {
                from: other,
                value: challengeTotalCost
            }),
            'Directory: The organization should have status Challenged.'
        );
    });

    it('Should not be possible to accept the challenge after the timeout', async () => {
        await aD.requestToAdd(ID, { from: requester });

        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await time.increase(responseTimeout + 1);

        await expectRevert(
            aD.acceptChallenge(ID, 'Accept.json', {
                from: other,
                value: challengeTotalCost
            }),
            'Directory: Time to accept the challenge has passed.'
        );
    });

    it('Should successfully execute the unchallenged request after the timeout and fire the event', async () => {
        await expectRevert(
            aD.executeTimeout(ID, { from: other }),
            'Directory: The organization must have a pending status and not be disputed.'
        );
        await aD.requestToAdd(ID, { from: requester });
        await expectRevert(
            aD.executeTimeout(ID, { from: other }),
            'Directory: Time to challenge the request must pass.'
        );

        await time.increase(executionTimeout + 1);
        // Check that anyone can execute the request.
        txExecute = await aD.executeTimeout(ID, { from: other });

        const orgData = await aD.organizationData(ID);
        assert.equal(
            orgData[1].toNumber(),
            5,
            'The organization should have status Registered'
        );
        assert.equal(
            await aD.registeredOrganizations(1),
            ID,
            'The organization should be in the registered array'
        );
        const orgIndex = (await aD.organizationsIndex(ID)).toNumber();
        assert.equal(orgIndex, 1, 'The organization has incorrect array index');

        // Check the event.
        assert.equal(
            txExecute.logs[0].event,
            'OrganizationAdded',
            'The event OrganizationAdded has not been created'
        );
        assert.equal(
            txExecute.logs[0].args._organization,
            ID,
            'The event has wrong organization'
        );
        assert.equal(
            txExecute.logs[0].args._index.toNumber(),
            1,
            'The event has wrong organization index'
        );

        // Check that can't execute 2 times.
        await expectRevert(
            aD.executeTimeout(ID, { from: other }),
            'Directory: The organization must have a pending status and not be disputed.'
        );
    });

    it('Should not be possible to execute the disputed request', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: other,
            value: challengeTotalCost
        });
        await time.increase(executionTimeout + 1);
        await expectRevert(
            aD.executeTimeout(ID, { from: other }),
            'Directory: The organization must have a pending status and not be disputed.'
        );
    });

    it('Should remove the organization and fire the event if the challenge was not accepted', async () => {
    // Register two organizations first to see how the registered array is managed.
        createTx = await orgId.createOrganization(
            soliditySha3('salt2'),
            soliditySha3('hash'),
            '',
            '',
            '',
            { from: requester }
        );
        const ID2 = createTx.logs[0].args.orgId;

        await aD.requestToAdd(ID, { from: requester });
        await aD.requestToAdd(ID2, { from: requester });
        await time.increase(executionTimeout + 1);

        await aD.executeTimeout(ID, { from: other });
        await aD.executeTimeout(ID2, { from: other });

        let count = (await aD.getOrganizationsCount(0, 0)).toNumber();
        assert.equal(count, 2, 'Incorrect number of registered organizations');
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            1000,
            'Incorrect token balance of the contract before execution'
        );
        assert.equal(
            (await aD.organizationsIndex(ID)).toNumber(),
            1,
            'The first organization has incorrect index'
        );
        assert.equal(
            (await aD.organizationsIndex(ID2)).toNumber(),
            2,
            'The second organization has incorrect index'
        );

        let index1Org = await aD.registeredOrganizations(1);
        assert.equal(index1Org, ID, 'Incorrect organization with 1 index');

        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await expectRevert(
            aD.executeTimeout(ID, { from: other }),
            'Directory: Time to respond to the challenge must pass.'
        );

        await time.increase(responseTimeout + 1);
        txExecute = await aD.executeTimeout(ID, { from: other });

        const orgData = await aD.organizationData(ID);
        assert.equal(
            orgData[1].toNumber(),
            0,
            'The organization should have status Absent'
        );
        assert.equal(orgData[4].toNumber(), 0, 'The lif stake should be 0');
        assert.equal(
            orgData[5].toNumber(),
            0,
            'The withdrawalRequest time should be 0'
        );

        const challengeData = await aD.getChallengeInfo(ID, 0);
        assert.equal(challengeData[2], true, 'The challenge should be resolved');

        assert.equal(
            (await lif.balanceOf(challenger)).toNumber(),
            500,
            'Incorrect token balance of the challenger'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            500,
            'Incorrect token balance of the contract after execution'
        );

        count = (await aD.getOrganizationsCount(0, 0)).toNumber();
        assert.equal(
            count,
            1,
            'Incorrect number of registered organizations after execution'
        );

        assert.equal(
            (await aD.organizationsIndex(ID)).toNumber(),
            0,
            'The removed organization should have 0 index'
        );
        assert.equal(
            (await aD.organizationsIndex(ID2)).toNumber(),
            1,
            'The remaining organization should have 1 index'
        );

        index1Org = await aD.registeredOrganizations(1);
        assert.equal(
            index1Org,
            ID2,
            'Incorrect organization with 1 index after execution'
        );

        assert.equal(
            txExecute.logs[0].event,
            'OrganizationRemoved',
            'The event OrganizationRemoved has not been created'
        );
        assert.equal(
            txExecute.logs[0].args._organization,
            ID,
            'The event has wrong organization'
        );
        const requestedOrgs = await aD.getRequestedOrganizations(0, 0);
        assert.equal(requestedOrgs.length, 0, 'Requested list should be empty');
    });

    it('Should allow challenger to withdraw funds if the challenge was timed out', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });

        let contribution = await aD.getContributions(ID, 0, 0, challenger);
        assert.equal(
            contribution[2].toNumber(),
            challengeTotalCost,
            'Challenger contribution has not been registered correctly'
        );

        await time.increase(responseTimeout + 1);
        await aD.executeTimeout(ID, { from: challenger });

        const oldBalance = await web3.eth.getBalance(challenger);
        const fr = await aD.getFeesAndRewards(challenger, ID, 0, 0);
        await aD.withdrawFeesAndRewards(challenger, ID, 0, 0, { from: governor });
        const newBalance = await web3.eth.getBalance(challenger);
        assert(
            new BN(oldBalance).add(new BN(fr)).eq(new BN(newBalance)),
            'Incorrect calculated fees and rewards'
        );
        assert(
            new BN(newBalance).eq(new BN(oldBalance).add(new BN(challengeTotalCost))),
            'Incorrect challenger balance after withdrawal'
        );

        contribution = await aD.getContributions(ID, 0, 0, challenger);
        assert.equal(
            contribution[2].toNumber(),
            0,
            'The contribution should be 0 after withdrawal'
        );
    });

    it('Should correctly make a withdrawal request for a registered organization', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await time.increase(executionTimeout + 1);
        await aD.executeTimeout(ID, { from: requester });

        await expectRevert(
            aD.makeWithdrawalRequest(ID, { from: other }),
            'Directory: Only organization owner or director can request a withdrawal.'
        );
        txWithdrawal = await aD.makeWithdrawalRequest(ID, { from: requester });

        const orgData = await aD.organizationData(ID);
        assert.equal(
            orgData[1].toNumber(),
            2,
            'The organization should have status WithdrawalRequested'
        );
        const orgIndex = (await aD.organizationsIndex(ID)).toNumber();
        assert.equal(orgIndex, 0, 'The organization should have 0 index');
        assert.equal(
            (await aD.getOrganizationsCount(0, 0)).toNumber(),
            0,
            'Organization count should be 0'
        );

        assert.equal(
            txWithdrawal.logs[0].event,
            'OrganizationRemoved',
            'The event OrganizationRemoved has not been created'
        );
        assert.equal(
            txWithdrawal.logs[0].args._organization,
            ID,
            'The event has wrong organization'
        );
    });

    it('Should not be possible to challenge after withdraw timeout', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await aD.makeWithdrawalRequest(ID, { from: requester });
        await time.increase(withdrawTimeout + 1);
        await expectRevert(
            aD.challengeOrganization(ID, 'Evidence.json', {
                from: challenger,
                value: challengeTotalCost
            }),
            'Directory: Time to challenge the withdrawn organization has passed.'
        );
    });

    it('Should withdraw tokens after withdrawal request has been made', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await expectRevert(
            aD.withdrawTokens(ID, { from: other }),
            'Directory: The organization has wrong status.'
        );
        await aD.makeWithdrawalRequest(ID, { from: requester });
        await expectRevert(
            aD.withdrawTokens(ID, { from: other }),
            'Directory: Tokens can only be withdrawn after the timeout.'
        );
        await time.increase(withdrawTimeout + 1);

        // Check that anybody can invoke the withdraw function.
        await aD.withdrawTokens(ID, { from: other });

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[1].toNumber(), 0, 'The status should be Absent');
        assert.equal(orgData[4].toNumber(), 0, 'The lif stake should be 0');
        assert.equal(
            orgData[5].toNumber(),
            0,
            'The withdrawal request time should be 0'
        );

        assert.equal(
            (await lif.balanceOf(requester)).toNumber(),
            tokenSupply,
            'Token balance of the org owner should be the initial value'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            0,
            'Token balance of the contract should be 0'
        );

        await expectRevert(
            aD.withdrawTokens(ID, { from: other }),
            'Directory: The organization has wrong status.'
        );
    });

    it('Should demand correct appeal fees and register that appeal fee has been paid', async () => {
        let roundInfo;
        await aD.requestToAdd(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await expectRevert(
            aD.fundAppeal(ID, 2, { from: challenger, value: 1e18 }),
            'Directory: The organization must have an open dispute.'
        );

        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.CHALLENGER);

        // Appeal fee is the same as arbitration fee for this arbitrator.
        const loserAppealFee =
      arbitrationCost +
      (arbitrationCost * loserStakeMultiplier) / MULTIPLIER_DIVISOR; // 1800

        await expectRevert(
            aD.fundAppeal(ID, 0, { from: requester, value: loserAppealFee }),
            'Directory: Invalid party.'
        );

        // Deliberately overpay to check that only required fee amount will be registered.
        await aD.fundAppeal(ID, 1, { from: requester, value: 1e18 });

        // Fund appeal again to see if it doesn't cause anything.
        await aD.fundAppeal(ID, 1, { from: requester, value: 1e18 });

        roundInfo = await aD.getRoundInfo(ID, 0, 1);

        assert.equal(
            roundInfo[1][1].toNumber(),
            loserAppealFee,
            'Registered fee of the requester is incorrect'
        );
        assert.equal(
            roundInfo[2][1],
            true,
            'Did not register that the requester successfully paid his fees'
        );

        assert.equal(
            roundInfo[1][2].toNumber(),
            0,
            'Should not register any payments for challenger'
        );
        assert.equal(
            roundInfo[2][2],
            false,
            'Should not register that challenger successfully paid fees'
        );
        assert.equal(
            roundInfo[3].toNumber(),
            loserAppealFee,
            'Incorrect FeeRewards value'
        );

        const winnerAppealFee =
      arbitrationCost +
      (arbitrationCost * winnerStakeMultiplier) / MULTIPLIER_DIVISOR; // 1200

        // Increase time to make sure winner can pay in 2nd half.
        await time.increase(appealTimeOut / 2 + 1);

        await aD.fundAppeal(ID, 2, {
            from: challenger,
            value: winnerAppealFee - 1
        }); // Underpay to see if it's registered correctly

        roundInfo = await aD.getRoundInfo(ID, 0, 1);

        assert.equal(
            roundInfo[1][2].toNumber(),
            winnerAppealFee - 1,
            'Registered partial fee of the challenger is incorrect'
        );
        assert.equal(
            roundInfo[2][2],
            false,
            'Should not register that the challenger successfully paid his fees after partial payment'
        );

        assert.equal(
            roundInfo[3].toNumber(),
            loserAppealFee + winnerAppealFee - 1,
            'Incorrect FeeRewards value after partial payment'
        );

        await aD.fundAppeal(ID, 2, { from: challenger, value: 1e18 });

        roundInfo = await aD.getRoundInfo(ID, 0, 1);

        assert.equal(
            roundInfo[1][2].toNumber(),
            winnerAppealFee,
            'Registered fee of challenger is incorrect'
        );
        assert.equal(
            roundInfo[2][2],
            true,
            'Did not register that challenger successfully paid his fees'
        );

        assert.equal(
            roundInfo[3].toNumber(),
            2000, // winnerAppealFee + loserAppealFee - arbitrationCost = 1800 + 1200 - 1000
            'Incorrect fee rewards value'
        );

        // If both sides pay their fees it starts new appeal round. Check that both sides have their value set to default.
        roundInfo = await aD.getRoundInfo(ID, 0, 2);
        assert.equal(
            roundInfo[2][1],
            false,
            'Appeal fee payment for requester should not be registered in the new round'
        );
        assert.equal(
            roundInfo[2][2],
            false,
            'Appeal fee payment for challenger should not be registered in the new round'
        );
    });

    it('Should correctly execute 0 ruling if the challenged organization was registered', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await time.increase(executionTimeout + 1);
        await aD.executeTimeout(ID, { from: requester });

        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.NONE);
        await time.increase(appealTimeOut + 1);
        await arbitrator.giveRuling(1, PARTY.NONE);

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[1].toNumber(), 5, 'The status should be Registered');
        assert.equal(orgData[4].toNumber(), 500, 'The lif stake should not change');
        assert.equal(
            orgData[5].toNumber(),
            0,
            'The withdrawal request time should stay default'
        );
        assert.equal(
            (await lif.balanceOf(requester)).toNumber(),
            99500,
            'Token balance of the owner should stay the same'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            500,
            'Token balance of the contract should stay the same'
        );

        const challengeData = await aD.getChallengeInfo(ID, 0);
        assert.equal(challengeData[2], true, 'The challenge should be resolved');
        assert.equal(challengeData[5].toNumber(), 0, 'The ruling should be 0');
    });

    it('Should correctly execute 0 ruling for the organization that was not registered', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.NONE);
        await time.increase(appealTimeOut + 1);
        await arbitrator.giveRuling(1, PARTY.NONE);

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[1].toNumber(), 0, 'The status should be Absent');
        assert.equal(orgData[4].toNumber(), 0, 'The lif stake should be 0');
        assert.equal(
            orgData[5].toNumber(),
            0,
            'The withdrawal request time should be 0'
        );
        assert.equal(
            (await lif.balanceOf(requester)).toNumber(),
            100000,
            'Token balance of the owner should be the initial value'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            0,
            'Token balance of the contract should be 0'
        );
    });

    it('Should correctly execute the ruling if the challenger won', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await time.increase(executionTimeout + 1);
        await aD.executeTimeout(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.CHALLENGER);
        await time.increase(appealTimeOut + 1);
        await arbitrator.giveRuling(1, PARTY.CHALLENGER);

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[1].toNumber(), 0, 'The status should be Absent');
        assert.equal(orgData[4].toNumber(), 0, 'The lif stake should be 0');
        assert.equal(
            orgData[5].toNumber(),
            0,
            'The withdrawal request time should be 0'
        );
        assert.equal(
            (await lif.balanceOf(challenger)).toNumber(),
            500,
            'The challenger did not receive the bounty'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            0,
            'Token balance of the contract should be 0'
        );

        const orgIndex = (await aD.organizationsIndex(ID)).toNumber();
        assert.equal(orgIndex, 0, 'The organization should have 0 index');

        count = (await aD.getOrganizationsCount(0, 0)).toNumber();
        assert.equal(
            count,
            0,
            'The contract should have 0 registered organizations'
        );
    });

    it('Should correctly execute the ruling if the requester won', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.REQUESTER);
        await time.increase(appealTimeOut + 1);
        await arbitrator.giveRuling(1, PARTY.REQUESTER);

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[1].toNumber(), 5, 'The status should be Registered');
        assert.equal(orgData[4].toNumber(), 500, 'The lif stake should not change');
        const orgIndex = (await aD.organizationsIndex(ID)).toNumber();
        assert.equal(orgIndex, 1, 'The organization should have 1 index');

        count = (await aD.getOrganizationsCount(0, 0)).toNumber();
        assert.equal(count, 1, 'The contract should have 1 registered organization');

        assert.equal(
            await aD.registeredOrganizations(1),
            ID,
            'The organization should be in the registered array'
        );
    });

    it('Should correctly execute the ruling if the requester won after withdrawal', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await time.increase(executionTimeout + 1);
        await aD.executeTimeout(ID, { from: requester });

        await aD.makeWithdrawalRequest(ID, { from: requester });

        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.REQUESTER);
        await time.increase(appealTimeOut + 1);
        await arbitrator.giveRuling(1, PARTY.REQUESTER);

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[1].toNumber(), 0, 'The status should be Absent');
        assert.equal(orgData[4].toNumber(), 0, 'The lif stake should be 0');
        assert.equal(
            orgData[5].toNumber(),
            0,
            'The withdrawal request time should be 0'
        );

        assert.equal(
            (await lif.balanceOf(requester)).toNumber(),
            tokenSupply,
            'The requester should have the initial token value'
        );
        assert.equal(
            (await lif.balanceOf(aD.address)).toNumber(),
            0,
            'Token balance of the contract should be 0'
        );
    });

    it('Should change the ruling if the loser paid appeal fees while winner did not', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.CHALLENGER);

        const loserAppealFee =
      arbitrationCost +
      (arbitrationCost * loserStakeMultiplier) / MULTIPLIER_DIVISOR;

        await aD.fundAppeal(ID, 1, { from: requester, value: loserAppealFee });

        await time.increase(appealTimeOut + 1);
        await arbitrator.giveRuling(1, PARTY.CHALLENGER);

        const orgData = await aD.organizationData(ID);
        assert.equal(orgData[1].toNumber(), 5, 'The status should be Registered');

        const challengeData = await aD.getChallengeInfo(ID, 0);
        assert.equal(challengeData[2], true, 'The challenge should be resolved');
        assert.equal(
            challengeData[5].toNumber(),
            1,
            'The ruling should be inverted in favor of the requester'
        );
    });

    it('Should withdraw fees correctly', async () => {
        await aD.requestToAdd(ID, { from: requester });
        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });
        await aD.acceptChallenge(ID, 'Accept.json', {
            from: requester,
            value: challengeTotalCost
        });

        await arbitrator.giveRuling(1, PARTY.CHALLENGER);

        // 1st appeal round.
        const loserAppealFee =
      arbitrationCost +
      (arbitrationCost * loserStakeMultiplier) / MULTIPLIER_DIVISOR; // 1800

        await aD.fundAppeal(ID, 1, {
            from: other,
            value: loserAppealFee * 0.8
        });
        await aD.fundAppeal(ID, 1, {
            from: requester,
            value: loserAppealFee * 0.8
        });

        const winnerAppealFee =
      arbitrationCost +
      (arbitrationCost * winnerStakeMultiplier) / MULTIPLIER_DIVISOR; // 1200

        await aD.fundAppeal(ID, 2, {
            from: challenger,
            value: winnerAppealFee * 0.1
        });
        await aD.fundAppeal(ID, 2, {
            from: challenger,
            value: winnerAppealFee * 0.3
        });

        await aD.fundAppeal(ID, 2, {
            from: other,
            value: winnerAppealFee * 5
        });

        // Check that can't withdraw if challenge is unresolved
        await expectRevert(
            aD.withdrawFeesAndRewards(requester, ID, 0, 1, { from: governor }),
            'Directory: The challenge must be resolved.'
        );

        await arbitrator.giveRuling(2, 2);
        await time.increase(appealTimeOut + 1);
        await arbitrator.giveRuling(2, 2);

        let oldBalanceRequester = await web3.eth.getBalance(requester);
        await aD.withdrawFeesAndRewards(requester, ID, 0, 1, {
            from: governor
        });
        let newBalanceRequester = await web3.eth.getBalance(requester);
        // Requester gets nothing since he only funded the losing side.
        assert(
            new BN(newBalanceRequester).eq(new BN(oldBalanceRequester)),
            'The balance of the requester should stay the same'
        );

        let oldBalanceChallenger = await web3.eth.getBalance(challenger);
        await aD.withdrawFeesAndRewards(challenger, ID, 0, 1, {
            from: governor
        });
        let newBalanceChallenger = await web3.eth.getBalance(challenger);
        assert(
            new BN(newBalanceChallenger).eq(
                new BN(oldBalanceChallenger).add(new BN(800))
            ), // Challenger paid 40% of his fees (feeRewards pool is 2000 (3000 paidFees - 1000 appealFees))
            'The challenger was not reimbursed correctly'
        );

        const oldBalanceCrowdfunder = await web3.eth.getBalance(other);
        await aD.withdrawFeesAndRewards(other, ID, 0, 1, { from: governor });
        const newBalanceCrowdfunder = await web3.eth.getBalance(other);
        assert(
            new BN(newBalanceCrowdfunder).eq(
                new BN(oldBalanceCrowdfunder).add(new BN(1200))
            ), // Crowdfunder paid 60% of the fees
            'The crowdfunder was not reimbursed correctly'
        );

        // Check that contributions are set to 0
        const contributions = await aD.getContributions(ID, 0, 1, other);
        assert.equal(
            contributions[1].toNumber(),
            0,
            'The 1st contribution should be set to 0'
        );
        assert.equal(
            contributions[2].toNumber(),
            0,
            'The 2nd contribution should be set to 0'
        );

        // Check withdraw from the 0 round
        oldBalanceRequester = await web3.eth.getBalance(requester);
        await aD.withdrawFeesAndRewards(requester, ID, 0, 0, {
            from: governor
        });
        newBalanceRequester = await web3.eth.getBalance(requester);
        assert(
            new BN(newBalanceRequester).eq(new BN(oldBalanceRequester)),
            'The balance of the requster should stay the same 0 round'
        );

        oldBalanceChallenger = await web3.eth.getBalance(challenger);
        await aD.withdrawFeesAndRewards(challenger, ID, 0, 0, {
            from: governor
        });
        newBalanceChallenger = await web3.eth.getBalance(challenger);
        assert(
            new BN(newBalanceChallenger).eq(
                new BN(oldBalanceChallenger).add(new BN(21000))
            ), // Challenger gets all feeRewards
            'The challenger was not reimbursed correctly 0 round'
        );
    });

    it('Should make governance changes', async () => {
        await expectRevert(
            aD.setSegment('Segment2', { from: other }),
            'The caller must be the governor.'
        );
        await aD.setSegment('Segment2', { from: governor });
        assert.equal(await aD.getSegment(), 'Segment2', 'Incorrect segment value');

        await expectRevert(
            aD.changeRequesterDeposit(555, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeRequesterDeposit(555, { from: governor });
        assert.equal(
            (await aD.requesterDeposit()).toNumber(),
            555,
            'Incorrect requesterDeposit value'
        );

        await expectRevert(
            aD.changeChallengeBaseDeposit(1111, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeChallengeBaseDeposit(1111, { from: governor });
        assert.equal(
            (await aD.challengeBaseDeposit()).toNumber(),
            1111,
            'Incorrect challengeBaseDeposit value'
        );

        await expectRevert(
            aD.changeExecutionTimeout(222, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeExecutionTimeout(222, { from: governor });
        assert.equal(
            (await aD.executionTimeout()).toNumber(),
            222,
            'Incorrect executionTimeout value'
        );

        await expectRevert(
            aD.changeResponseTimeout(134, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeResponseTimeout(134, { from: governor });
        assert.equal(
            (await aD.responseTimeout()).toNumber(),
            134,
            'Incorrect responseTimeout value'
        );

        await expectRevert(
            aD.changeWithdrawTimeout(66, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeWithdrawTimeout(66, { from: governor });
        assert.equal(
            (await aD.withdrawTimeout()).toNumber(),
            66,
            'Incorrect withdrawTimeout value'
        );

        await expectRevert(
            aD.changeSharedStakeMultiplier(5, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeSharedStakeMultiplier(5, { from: governor });
        assert.equal(
            (await aD.sharedStakeMultiplier()).toNumber(),
            5,
            'Incorrect sharedStakeMultiplier value'
        );

        await expectRevert(
            aD.changeWinnerStakeMultiplier(2, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeWinnerStakeMultiplier(2, { from: governor });
        assert.equal(
            (await aD.winnerStakeMultiplier()).toNumber(),
            2,
            'Incorrect winnerStakeMultiplier value'
        );

        await expectRevert(
            aD.changeLoserStakeMultiplier(8, { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeLoserStakeMultiplier(8, { from: governor });
        assert.equal(
            (await aD.loserStakeMultiplier()).toNumber(),
            8,
            'Incorrect loserStakeMultiplier value'
        );

        await expectRevert(
            aD.changeArbitrator(other, '0xff', { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeArbitrator(other, '0xff', { from: governor });
        assert.equal(await aD.arbitrator(), other, 'Incorrect arbitrator address');
        assert.equal(
            await aD.arbitratorExtraData(),
            '0xff',
            'Incorrect extraData value'
        );

        await expectRevert(
            aD.changeMetaEvidence('.json', { from: other }),
            'The caller must be the governor.'
        );
        await aD.changeMetaEvidence('.json', { from: governor });
        assert.equal(
            (await aD.metaEvidenceUpdates()).toNumber(),
            1,
            'Incorrect metaEvidenceUpdates value'
        );
    });

    it('Should submit evidence and fire the event', async () => {
        let txEvidence;
        await expectRevert(
            aD.submitEvidence(ID, 'NewEvidence.Json', { from: other }),
            'Directory: The organization never had a request.'
        );

        await aD.requestToAdd(ID, { from: requester });
        txEvidence = await aD.submitEvidence(ID, 'NewEvidence.Json', {
            from: other
        });

        let evidenceGroupID = parseInt(soliditySha3(ID, 0), 16);
        assert.equal(
            txEvidence.logs[0].event,
            'Evidence',
            'The event Evidence has not been created'
        );
        assert.equal(
            txEvidence.logs[0].args._arbitrator,
            arbitrator.address,
            'The event has wrong arbitrator'
        );
        assert.equal(
            txEvidence.logs[0].args._evidenceGroupID,
            evidenceGroupID,
            'The event has wrong evidenceGroup ID'
        );
        assert.equal(
            txEvidence.logs[0].args._party,
            other,
            'The event has wrong party'
        );
        assert.equal(
            txEvidence.logs[0].args._evidence,
            'NewEvidence.Json',
            'The event has wrong evidence'
        );

        await aD.challengeOrganization(ID, 'Evidence.json', {
            from: challenger,
            value: challengeTotalCost
        });

        txEvidence = await aD.submitEvidence(ID, 'ChallengeEvidence.Json', {
            from: challenger
        });

        evidenceGroupID = parseInt(soliditySha3(ID, 1), 16);
        assert.equal(
            txEvidence.logs[0].event,
            'Evidence',
            'The second event Evidence has not been created'
        );
        assert.equal(
            txEvidence.logs[0].args._arbitrator,
            arbitrator.address,
            'The second event has wrong arbitrator'
        );
        assert.equal(
            txEvidence.logs[0].args._evidenceGroupID,
            evidenceGroupID,
            'The second event has wrong evidenceGroup ID'
        );
        assert.equal(
            txEvidence.logs[0].args._party,
            challenger,
            'The second event has wrong party'
        );
        assert.equal(
            txEvidence.logs[0].args._evidence,
            'ChallengeEvidence.Json',
            'The second event has wrong evidence'
        );

        await time.increase(responseTimeout + 1);
        await aD.executeTimeout(ID, { from: challenger });

        await expectRevert(
            aD.submitEvidence(ID, '1.Json', { from: other }),
            'Directory: The challenge must not be resolved.'
        );
    });
});
