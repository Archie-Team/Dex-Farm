const Factory = artifacts.require('Factory.sol');
const SwapLibrary = artifacts.require('UniswapV2Library.sol');
const Swap = artifacts.require('Swap.sol');
const Staking = artifacts.require('Staking.sol');
const Math = artifacts.require('Math.sol');



module.exports = async function (deployer, _network, addresses) {
  await deployer.deploy(Factory, addresses[0])
  await deployer.deploy(SwapLibrary)
  const factory = await Factory.deployed()
  await factory.createPair();

  const _showPair = await factory.ShowPair();
  const BULC = await factory.BULC();
  await deployer.link(SwapLibrary, Swap);
  await deployer.deploy(Swap, _showPair);
  console.log(`show pair is : ${_showPair}`)
  await deployer.deploy(Math)

  await deployer.link(Math, Staking);
  await deployer.link(SwapLibrary, Staking);
  await deployer.deploy(Staking,_showPair,BULC)

  
};