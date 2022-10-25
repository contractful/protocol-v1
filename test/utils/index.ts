import {Contract, ContractFactory} from 'ethers';
import {
  artifacts,
  deployments,
  ethers,
  getNamedAccounts,
  getUnnamedAccounts,
} from 'hardhat';

import {deployMockContract} from '@ethereum-waffle/mock-contract';

import {FDAI__factory, Manager, Manager__factory} from '../../typechain';

export async function setupUsers<
  T extends {[contractName: string]: Contract | ContractFactory}
>(addresses: string[], contracts: T): Promise<({address: string} & T)[]> {
  const users: ({address: string} & T)[] = [];
  for (const address of addresses) {
    users.push(await setupUser(address, contracts));
  }
  return users;
}

export async function setupUser<
  T extends {[contractName: string]: Contract | ContractFactory}
>(address: string, contracts: T): Promise<{address: string} & T> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const user: any = {address}; // user type is cast on the return statement
  for (const key of Object.keys(contracts)) {
    user[key as keyof typeof user] = contracts[key].connect(
      await ethers.getSigner(address)
    );
  }
  return user as {address: string} & T;
}

// eslint-disable-next-line @typescript-eslint/explicit-module-boundary-types
export async function setupFixture(fixtureName: string) {
  await deployments.fixture(fixtureName);
  const {deployer} = await getNamedAccounts();
  const signerDeployer = await ethers.getSigner(deployer);

  const IERC20 = await artifacts.readArtifact('IERC20');
  const Manager = await artifacts.readArtifact('Manager');

  const AgreementTokenM = await deployMockContract(signerDeployer, IERC20.abi);
  const ManagerM = await deployMockContract(signerDeployer, Manager.abi);

  const contracts = {
    Manager: <Manager>await ethers.getContract('Manager'),
    ManagerF: <Manager__factory>await ethers.getContractFactory('Manager'),

    fDAIF: <FDAI__factory>await ethers.getContractFactory('fDAI'),
  };

  const users = await setupUsers(await getUnnamedAccounts(), contracts);

  return {
    ...contracts,
    mocks: {
      AgreementToken: AgreementTokenM,
      Manager: ManagerM,
    },
    users,
    deployer: await setupUser(deployer, contracts),
  };
}

export async function getTimeStamp(): Promise<number> {
  const blockNum = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNum);
  return block.timestamp;
}
