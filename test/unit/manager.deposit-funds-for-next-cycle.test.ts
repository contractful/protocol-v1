import {BigNumber} from 'ethers';
import {deployments} from 'hardhat';
import {Manager} from '../../typechain';
import {setupFixture} from '../utils';
import {User} from '../utils/types';
import {assert, expect} from './helpers/chai-setup';
import {setupTestContracts} from './utils';

const setup = deployments.createFixture(async () => {
  return setupFixture('all');
});

describe('Manager - deposit', async function () {
  let contractee: User, contractor: User, user1: User;
  let Manager: Manager;
  let agreementID: BigNumber;

  beforeEach(async function () {
    const {deployer, mocks, users} = await setup();
    const {
      deployedManager,
      testContractor,
      agreementID: agreementIDTemp,
      testContractee,
      testUser1,
    } = await setupTestContracts(deployer, mocks, users);

    Manager = deployedManager;
    contractee = testContractee;
    contractor = testContractor;
    agreementID = agreementIDTemp; // agreementIDTemp == agreementID
    user1 = testUser1;
  });

  it('Depositing funds when an agreement is not active should return false', async function () {

    const { hasDeposited } = await contractee.Manager.depositFundsForNextCycle(agreementID);

    assert(!hasDeposited);
    // await expect(
    //   contractee.Manager.depositFundsForNextCycle(agreementID)
    // ).to.be.revertedWith('MG_NOT_ONGOING');
  });

  // it('Depositing funds as an unauthorized user should revert', async function () {
  //   await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
  //     Manager,
  //     'AgreementActivated'
  //   );

  //   await expect(
  //     user1.Manager.depositFundsForNextCycle(agreementID)
  //   ).to.be.revertedWith('MG_UNAUTHORIZED');
  // });

  it('Depositing funds twice for the same cycle should return false', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );
    const { hasDeposited } = await contractee.Manager.depositFundsForNextCycle(agreementID);

    assert(!hasDeposited);
    // await expect(
    //   contractee.Manager.depositFundsForNextCycle(agreementID)
    // ).to.be.revertedWith('MG_FUNDS_ALREADY_SECURED');
  });
});
