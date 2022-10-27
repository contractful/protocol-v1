import {BigNumber} from 'ethers';
import {ethers, getNamedAccounts} from 'hardhat';
import {
  ACCEPTANCE_PERIOD,
  AGREEMENT_DURATION,
  PAYMENT_CYCLE_DURATION,
} from './../../utils/constants';

import {Manager} from '../../../typechain';
import {getTimeStamp, setupUser} from '../../utils';
import {GOVERNANCE_ROLE, PAYMENT_CYCLE_AMOUNT} from '../../utils/constants';
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
    acceptanceDeadline: (await getTimeStamp()) + ACCEPTANCE_PERIOD,
    maturityDate: (await getTimeStamp()) + AGREEMENT_DURATION,
    paymentCycleDuration: PAYMENT_CYCLE_DURATION,
    paymentCycleAmount: PAYMENT_CYCLE_AMOUNT,
    underlayingToken: agreementTokenAddress,
    contractor: testContractor.address,
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

// export async function getDescriptionSignature(
//   wallet: Wallet,
//   manager: Manager,
//   description: string,
//   contractor: string
// ): Promise<Signature> {
//   const [nonce, name, version, chainId] = await Promise.all([
//     manager.nonce(),
//     manager.name(),
//     '1',
//     wallet.getChainId(),
//   ]);

//   return splitSignature(
//     await wallet._signTypedData(
//       {
//         name,
//         version,
//         chainId,
//         verifyingContract: manager.address,
//       },
//       {
//         Permit: [
//           {
//             name: 'description',
//             type: 'string',
//           },
//           {
//             name: 'nonce',
//             type: 'uint256',
//           },
//         ],
//       },
//       {
//         description,
//         nonce,
//       }
//     )
//   );
// }
