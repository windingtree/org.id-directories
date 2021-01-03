const { TestHelper } = require('@openzeppelin/cli');
const { Contracts } = require('@openzeppelin/upgrades');

const { orgIdSetup } = require('./orgid');

/**
 * Creates directory
 * @param {string} orgIdOwner The addres of the OrgId owner
 * @param {string} directoryOwner The address of the directory owner
 * @param {string} segmentName Name of the directory
 * @returns {Promise<{Object}>} Object with directory and orgId instances
 */
module.exports.createDirectory = async (
    orgIdOwner,
    directoryOwner,
    segmentName
) => {
    const Directory = Contracts.getFromLocal('Directory');
    const orgId = await orgIdSetup(orgIdOwner);
    const project = await TestHelper({ from: directoryOwner });
    const directory = await project.createProxy(Directory, {
        initMethod: 'initialize',
        initArgs: [
            directoryOwner,
            segmentName,
            orgId.address
        ]
    });

    return {
        project,
        directory,
        orgId
    };
};
