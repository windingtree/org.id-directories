global.web3 = web3;
const keys = require('../keys.json');

const EnhancedAppealableArbitrator = artifacts.require('EnhancedAppealableArbitrator');

const main = async () => {

    const arbitrator = await EnhancedAppealableArbitrator.new(
        1000,
        keys.key,
        '0x85',
        180,
        {
            from: keys.key
        }
    );
    console.log('EnhancedAppealableArbitrator:', arbitrator.address);
};

module.exports = callback => main()
    .then(() => callback())
    .catch(err => callback(err));
