const { TestHelper } = require('@openzeppelin/cli');
const { Contracts } = require('@openzeppelin/upgrades');

/**
 * Generates an id on the base of string and solt
 * @param {string} string Part of the base for id generation
 * @param {atring} [solt=Math.random().toString()] Solt string
 */
const generateId = (string, solt = Math.random().toString()) => web3.utils.keccak256(`${string}${solt}`);
module.exports.generateId = generateId;

const generateSalt = () => web3.utils.keccak256(Math.random().toString());
module.exports.generateSalt = generateSalt;

/**
 * Create new ORG.ID instance
 * @param {string} owner Org.Id owner address
 * @returns {Promise<{Object}>} OrgId contact instancr
 */
module.exports.orgIdSetup = async (owner) => {
    const OrgId = Contracts.getFromNodeModules('@windingtree/org.id', 'OrgId');
    const project = await TestHelper({
        from: owner
    });
    await project.setImplementation(
        OrgId,
        'OrgId'
    );
    return await project.createProxy(OrgId, {
        initMethod: 'initialize',
        initArgs: []
    });
};

/**
 * Create an organizations
 * @param {Object} orgId OrgId contract instance
 * @param {string} from The address of the organization owner
 * @param {string} salt Organization Id salt
 * @param {string} uri Url to orgIdJson
 * @param {string} hash Hash of the orgIdJson
 * @returns {Promise<{string}>} Organization Id
 */
module.exports.createOrganization = async (
    orgId,
    from,
    salt = generateSalt(),
    uri = 'path/to/orgIdJson',
    hash = web3.utils.soliditySha3(uri)
) => {
    const result = await orgId
        .methods['createOrganization(bytes32,bytes32,string,string,string)'](
            salt,
            hash,
            uri,
            '',
            ''
        )
        .send({ from });
    return result.events.OrganizationCreated.returnValues.orgId;
};

/**
 * Toggle organization state
 * @param {Object} orgId OrgId contract instance
 * @param {string} from The address of the organization owner
 * @param {string} id Organization Id
 * @returns {Promise<{bool}>} Organization state
 */
module.exports.toggleActiveState = async (
    orgId,
    from,
    id
) => {
    await orgId
        .methods['toggleActiveState(bytes32)'](id)
        .send({ from });
    const organization = await orgId
        .methods['getOrganization(bytes32)'](id)
        .call();
    return organization.state;
};

/**
 * Create organizational unit
 * @param {Object} orgId OrgId contract instance
 * @param {string} from The address of the organization owner
 * @param {string} salt Organization Id salt
 * @param {string} director Organization director address
 * @param {string} uri Url to orgIdJson
 * @param {string} hash Hash of the orgIdJson
 * @returns {Promise<{bool}>} Subsidiary Id
 */
module.exports.createUnit = async (
    orgId,
    from,
    salt,
    director,
    parentOrgId = generateId(`${from}${Math.random().toString()}`),
    uri = 'path/to/orgIdJson',
    hash = web3.utils.soliditySha3(uri)
) => {
    const result = await orgId
        .methods['createUnit(bytes32,bytes32,address,bytes32,string,string,string)'](
            salt,
            parentOrgId,
            director,
            hash,
            uri,
            '',
            ''
        )
        .send({ from });
    return result.events.UnitCreated.returnValues.unitOrgId;
};
