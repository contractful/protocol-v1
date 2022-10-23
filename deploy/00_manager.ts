import debugModule from 'debug';
import {DeployFunction} from 'hardhat-deploy/types';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {Manager} from '../typechain';

import {CHALLENGE_DURATION} from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const log = debugModule('deploy-setup');
  log.enabled = true;
  //   eslint-disable-next-line @typescript-eslint/no-explicit-any
  const {deployments} = hre as any;
  const {ethers, getNamedAccounts, network} = hre;

  // keep ts support on hre members
  const {deployer, governance} = await getNamedAccounts();
  const {deploy, catchUnknownSigner} = deployments;

  log('Governance: ' + governance);
  log('Deployer: ' + deployer);

  // Deploy proxy
  await catchUnknownSigner(
    deploy('Manager', {
      contract: 'Manager',
      from: deployer,
      proxy: {
        owner: governance,
        proxy: true,
        execute: {
          init: {
            methodName: 'initialize',
            args: [CHALLENGE_DURATION, governance],
          },
        },
      },
      log: true,
    })
  );

  const ManagerDeployer = <Manager>(
    await ethers.getContract('Manager', deployer)
  );

  // Print all contracts info pretty
  log('Manager proxy address: ' + ManagerDeployer.address);
};
export default func;
func.tags = ['all', 'manager', 'test', 'local', 'production'];
