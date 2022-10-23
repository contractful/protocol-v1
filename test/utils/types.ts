import {BigNumber, Contract} from 'ethers';

import {MockContract} from '@ethereum-waffle/mock-contract';

import {Manager, Manager__factory} from '../../typechain';

export interface AgreementCreationParams {
  acceptanceDeadline: BigNumber;
  maturityDate: BigNumber;
  paymentCycleDuration: BigNumber;
  paymentCycleAmount: BigNumber;
  underlayingToken: string;
  contractor: string;
}
export type Deployer = {
  Manager: Manager;
  ManagerF: Manager__factory;
};

export type Mocks = {
  AgreementToken: MockContract;
  Manager: MockContract;
};

export type User = {
  address: string;
  TestToken?: Contract;
  Manager: Manager | MockContract;
};
