const { TestHelper } = require('@openzeppelin/cli');
const { Contracts } = require('@openzeppelin/upgrades');

/**
 * Create new ORG.ID instance
 * @param {string} owner Org.Id owner address
 * @returns {Promise<{string}>}
 */
module.exports = async (owner) => {
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
