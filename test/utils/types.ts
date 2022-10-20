import {BigNumber, Contract} from 'ethers';

import {MockContract} from '@ethereum-waffle/mock-contract';

import {Manager, Manager__factory} from '../../typechain';

export interface AgreementCreationParams {
  maturityDate: BigNumber;
  paymentCycleDuration: BigNumber;
  paymentCycleAmount: BigNumber;
  underlayingToken: string;
  contractor: string;
  contractee: string;
}
export type Deployer = {
  Manager: Manager;
  ManagerF: Manager__factory;
};

export type Mocks = {
  SafeERC20: MockContract;
  AgreementToken: MockContract;
  Manager: MockContract;
};

export type User = {
  address: string;
  Token?: Contract;
  Manager: Manager | MockContract;
};
