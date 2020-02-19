const { TestHelper } = require('@openzeppelin/cli');
const { Contracts } = require('@openzeppelin/upgrades');

/**
 * Generates an id on the base of string and solt
 * @param {string} string Part of the base for id generation
 * @param {atring} [solt=Math.random().toString()] Solt string
 */
const generateId = (string, solt = Math.random().toString()) => web3.utils.keccak256(`${string}${solt}`);
module.exports.generateId = generateId;

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
        initArgs: [
            owner
        ]
    });
};

/**
 * Create an organizations
 * @param {Object} orgId OrgId contract instance
 * @param {string} from The address of the organization owner
 * @param {string} id Organization Id
 * @param {string} uri Url to orgIdJson
 * @param {string} hash Hash of the orgIdJson
 * @returns {Promise<{string}>} Organization Id
 */
module.exports.createOrganization = async (
    orgId,
    from,
    id = generateId(`${from}${Math.random().toString()}`),
    uri = 'path/to/orgIdJson',
    hash = web3.utils.soliditySha3(uri)
) => {
    await orgId
        .methods['createOrganization(bytes32,string,bytes32)'](
            id,
            uri,
            hash
        )
        .send({ from });
    return id;
};

/**
 * Toggle organization state
 * @param {Object} orgId OrgId contract instance
 * @param {string} from The address of the organization owner
 * @param {string} id Organization Id
 * @returns {Promise<{bool}>} Organization state
 */
module.exports.toggleOrganization = async (
    orgId,
    from,
    id
) => {
    await orgId
        .methods['toggleOrganization(bytes32)'](id)
        .send({ from });
    const organization = await orgId
        .methods['getOrganization(bytes32)'](id)
        .call();
    return organization.state;
};

/**
 * Create subsidiary organization
 * @param {Object} orgId OrgId contract instance
 * @param {string} from The address of the organization owner
 * @param {string} id Organization Id
 * @param {string} director Organization director address
 * @param {string} uri Url to orgIdJson
 * @param {string} hash Hash of the orgIdJson
 * @returns {Promise<{bool}>} Subsidiary Id
 */
module.exports.createSubsidiary = async (
    orgId,
    from,
    id,
    director,
    subOrgId = generateId(`${from}${Math.random().toString()}`),
    uri = 'path/to/orgIdJson',
    hash = web3.utils.soliditySha3(uri)
) => {
    await orgId
        .methods['createSubsidiary(bytes32,bytes32,address,string,bytes32)'](
            id,
            subOrgId,
            director,
            uri,
            hash
        )
        .send({ from });
    return subOrgId;
};
