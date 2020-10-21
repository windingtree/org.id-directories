/**
 * Deployment and configuration of the EAA
 */
global.web3 = web3;
const EnhancedAppealableArbitrator = artifacts.require('EnhancedAppealableArbitrator');

const main = async () => {
    const accounts = await web3.eth.getAccounts();
    const arbitrationFee = 1000;
    const appealTimeOut = 86400; // 24 hours
    const arbitratorExtraData = '0x85';
    const arbitrator = await EnhancedAppealableArbitrator.new(
        arbitrationFee,
        accounts[1],
        arbitratorExtraData,
        appealTimeOut,
        {
            from: accounts[1]
        }
    );
    await arbitrator.changeArbitrator(
        arbitrator.address,
        {
            from: accounts[1]
        }
    );
    await arbitrator.createDispute(
        3,
        arbitratorExtraData,
        {
            from: accounts[1],
            value: arbitrationFee
        }
    );
    console.log('EnhancedAppealableArbitrator:', arbitrator.address);
    console.log('EAA Owner:', accounts[1]);
};

module.exports = callback => main()
    .then(() => callback())
    .catch(err => callback(err));
