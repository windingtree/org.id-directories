global.web3 = web3;
const { parseArgv } = require('../tools/utils/cli');
const Lif = artifacts.require('LifTest');

const main = async () => {
    const { from } = parseArgv(process.argv, 6);

    const lif = await Lif.new('Lif', 'LIF', 18, '1000000', {
        from
    });

    console.log('LIF token address:', lif.address);
};

module.exports = callback => main()
    .then(() => callback())
    .catch(err => callback(err));
