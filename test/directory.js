const { Contracts, ZWeb3 } = require('@openzeppelin/upgrades');

const { assertRevert, assertEvent } = require('./helpers/assertions');
const {
    createOrganization,
    createSubsidiary,
    toggleOrganization,
    generateId
} = require('./helpers/orgid');
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

const Directory = Contracts.getFromLocal('Directory');
const DirectoryUpgradeability = Contracts.getFromLocal('DirectoryUpgradeability');
const FakeOrgId = Contracts.getFromLocal('FakeOrgId');

require('chai').should();

contract('Directory', accounts => {
    
    const orgIdOwner = accounts[1];
    const dirOwner = accounts[2];
    const organizationOwner = accounts[3];
    const subsidiaryDirector = accounts[4];
    const nonOwner = accounts[5];

    const segmentName = 'hotels';
    let project;
    let dir;
    let orgId;
    
    beforeEach(async () => {
        const setup = await createDirectory(orgIdOwner, dirOwner, segmentName);
        orgId = setup.orgId;
        project = setup.project;
        dir = setup.directory;
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

        describe('#add(bytes32)', () => {
            let organizations;

            beforeEach(async () => {
                // Create some organizations
                organizations = await Promise.all([
                    {
                        orgId,
                        from: organizationOwner
                    },
                    {
                        orgId,
                        from: organizationOwner
                    },
                    {
                        orgId,
                        from: organizationOwner
                    }
                ].map(o => createOrganization(
                    o.orgId,
                    o.from
                )));
            });

            it('should fail if zero bytes been provided as organization id', async () => {
                await assertRevert(
                    dir
                        .methods['add(bytes32)'](zeroBytes)
                        .send({ from: organizationOwner }),
                    'Directory: Invalid organization Id'
                );
            });

            it('should fail if the same organization has been added before', async () => {
                await dir
                    .methods['add(bytes32)'](organizations[0])
                    .send({ from: organizationOwner });
                await assertRevert(
                    dir
                        .methods['add(bytes32)'](organizations[0])
                        .send({ from: organizationOwner }),
                    'Directory: Cannot add organization twice'
                );
            });

            it('should fail if provided unknown organization', async () => {
                await assertRevert(
                    dir
                        .methods['add(bytes32)'](generateId(organizations[0]))
                        .send({ from: organizationOwner }),
                    'OrgId: Organization with given orgId not found'
                );
            });

            it('should fail if called not by organization owner', async () => {
                await assertRevert(
                    dir
                        .methods['add(bytes32)'](organizations[0])
                        .send({ from: nonOwner }),
                    'Directory: Only organization owner or director can add the organization'
                );
            });

            it('should fail if provided disabled organization', async () => {
                await toggleOrganization(
                    orgId,
                    organizationOwner,
                    organizations[0]
                );
                await assertRevert(
                    dir
                        .methods['add(bytes32)'](organizations[0])
                        .send({ from: organizationOwner }),
                    'Directory: Only enabled organizations can be added'
                );
            });

            it('should fail if ptovided subsidiary with non confirmed director ownership', async () => {
                const subId = await createSubsidiary(
                    orgId,
                    organizationOwner,
                    organizations[0],
                    subsidiaryDirector
                );
                await assertRevert(
                    dir
                        .methods['add(bytes32)'](subId)
                        .send({ from: subsidiaryDirector }),
                    'Directory: Only subsidiaries with confirmed director ownership can be added'
                );
            });

            it('should add origanization', async () => {
                const result = await dir
                    .methods['add(bytes32)'](organizations[0])
                    .send({ from: organizationOwner });
                assertEvent(result, 'OrganizationAdded', [
                    [
                        'organization',
                        p => (p).should.equal(organizations[0])
                    ],
                    [
                        'index',
                        p => (Number(p)).should.not.equal(0)
                    ]
                ]);
                const orgs = await dir
                    .methods['getOrganizations()']()
                    .call();
                (orgs).should.to.be.an('array').that.include(organizations[0]);
            });
        });

        describe('#remove(bytes32)', () => {
            let organization;

            beforeEach(async () => {
                organization = await createOrganization(
                    orgId,
                    organizationOwner
                );
                await dir
                    .methods['add(bytes32)'](organization)
                    .send({ from: organizationOwner });
            });
            
            it('should fail if non registered organization has been provided', async () => {
                await assertRevert(
                    dir
                        .methods['remove(bytes32)'](generateId('unknown'))
                        .send({ from: organizationOwner }),
                    'Directory: Organization with given Id not found'
                );
            });

            it('should fail if called not by an organization owner or director', async () => {
                await assertRevert(
                    dir
                        .methods['remove(bytes32)'](organization)
                        .send({ from: nonOwner }),
                    'Directory: Only organization owner or director can remove the organization'
                );
            });

            it('should remove organization', async () => {
                let orgs = await dir
                    .methods['getOrganizations()']()
                    .call();
                (orgs).should.to.be.an('array').that.include(organization);
                const result = await dir
                    .methods['remove(bytes32)'](organization)
                    .send({ from: organizationOwner });
                assertEvent(result, 'OrganizationRemoved', [
                    [
                        'organization',
                        p => (p).should.equal(organization)
                    ]
                ]);
                orgs = await dir
                    .methods['getOrganizations()']()
                    .call();
                (orgs).should.to.be.an('array').that.not.include(organization);
            });
        });

        describe('#getOrganizations()', () => {

            it('should return empty array if organization are not been added before', async () => {
                const orgs = await dir
                    .methods['getOrganizations()']()
                    .call();
                (orgs).should.to.be.an('array');
                (orgs.length).should.equal(0);
            });

            it('should return empty array if organizations been added but removed', async () => {
                const organization = await createOrganization(
                    orgId,
                    organizationOwner
                );
                await dir
                    .methods['add(bytes32)'](organization)
                    .send({ from: organizationOwner });
                let orgs = await dir
                    .methods['getOrganizations()']()
                    .call();
                (orgs).should.to.be.an('array').that.include(organization);
                await dir
                    .methods['remove(bytes32)'](organization)
                    .send({ from: organizationOwner });
                orgs = await dir
                    .methods['getOrganizations()']()
                    .call();
                (orgs).should.to.be.an('array');
                (orgs.length).should.equal(0);
            });

            it('should return array of added organizations', async () => {
                const organization = await createOrganization(
                    orgId,
                    organizationOwner
                );
                await dir
                    .methods['add(bytes32)'](organization)
                    .send({ from: organizationOwner });
                let orgs = await dir
                    .methods['getOrganizations()']()
                    .call();
                (orgs).should.to.be.an('array').that.include(organization);
            });
        });
    });
});
