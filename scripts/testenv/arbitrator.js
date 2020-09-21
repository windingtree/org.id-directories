global.web3 = web3;
const { parseArgv } = require('../tools/utils/cli');
const Arbitrator = artifacts.require('EnhancedAppealableArbitrator');

const arbitrationCost = 1000;
const arbitratorExtraData = '0x85';
const appealTimeOut = 180;

const main = async () => {
    const { governor } = parseArgv(process.argv, 6);

    const arbitrator = await Arbitrator.new(
        arbitrationCost,
        governor,
        arbitratorExtraData,
        appealTimeOut,
        {
            from: governor
        }
    );

    console.log('Arbitrator address:', arbitrator.address);
    console.log('Arbitration Cost:', arbitrationCost);
    console.log('Extra Data:', arbitratorExtraData);
    console.log('Appeal TimeOut:', appealTimeOut);
};

module.exports = callback => main()
    .then(() => callback())
    .catch(err => callback(err));
