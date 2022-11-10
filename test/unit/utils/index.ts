import {BigNumber} from 'ethers';
import {ethers, getNamedAccounts} from 'hardhat';
import {
  AGREEMENT_DURATION,
  ONE_HOUR,
  PAYMENT_CYCLE_DURATION,
} from './../../utils/constants';

import {Manager} from '../../../typechain';
import {getTimeStamp, setupUser} from '../../utils';
import {
  DESCRIPTION_URI,
  GOVERNANCE_ROLE,
  PAYMENT_CYCLE_AMOUNT,
} from '../../utils/constants';
import {Deployer, Mocks, User} from '../../utils/types';

//Functional setup for Position Contract Tests :
//Deploying Contracts, mocking return values, returning users
export const setupTestContracts = async (
  deployer: Deployer,
  mocks: Mocks,
  users: ({address: string} & Deployer)[]
): Promise<{
  deployedManager: Manager;
  governance: User;
  testContractee: User;
  testContractor: User;
  testUser1: User;
  agreementID: BigNumber;
  agreementTokenAddress: string;
}> => {
  const {governance: governanceAddress} = await getNamedAccounts();

  const deployedManager = <Manager>(
    await ethers.getContract('Manager', governanceAddress)
  );

  // setup users
  const governance = await setupUser(users[1].address, {
    Manager: deployedManager,
  });
  await deployedManager.grantRole(GOVERNANCE_ROLE, governance.address);

  const testContractee = await setupUser(users[2].address, {
    Manager: deployedManager,
  });

  const testContractor = await setupUser(users[3].address, {
    Manager: deployedManager,
  });

  const testUser1 = await setupUser(users[4].address, {
    Manager: deployedManager,
  });

  // setup mock responses
  await mocks.AgreementToken.mock.transfer.returns(true);
  await mocks.AgreementToken.mock.transferFrom.returns(true);

  // create agreement
  const agreementID = await deployedManager.agreementNonce();
  const agreementTokenAddress = mocks.AgreementToken.address;
  await testContractee.Manager.createAgreement({
    beginningDate: (await getTimeStamp()) + ONE_HOUR * 24,
    maturityDate: (await getTimeStamp()) + AGREEMENT_DURATION,
    paymentCycleDuration: PAYMENT_CYCLE_DURATION,
    paymentCycleAmount: PAYMENT_CYCLE_AMOUNT,
    underlayingToken: agreementTokenAddress,
    contractor: testContractor.address,
    descriptionURI: DESCRIPTION_URI,
  });

  return {
    agreementID,
    agreementTokenAddress,
    deployedManager,
    governance,
    testContractee,
    testContractor,
    testUser1,
  };
};
