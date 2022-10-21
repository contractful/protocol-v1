import {BigNumber} from 'ethers';
import {deployments} from 'hardhat';
import {Manager} from '../../typechain';
import {setupFixture} from '../utils';
import {User} from '../utils/types';
import {expect} from './helpers/chai-setup';
import {setupTestContracts} from './utils';

const setup = deployments.createFixture(async () => {
  return setupFixture('all');
});

describe('Manager - migrateFunds', async function () {
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

  it('Depositing funds when an agreement is not active should revert', async function () {
    await expect(
      contractee.Manager.depositFundsForNextCycle(agreementID)
    ).to.be.revertedWith('MG_AGREEMENT_INACTIVE');
  });

  it('Depositing funds as an unauthorized user should revert', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );

    await expect(
      user1.Manager.depositFundsForNextCycle(agreementID)
    ).to.be.revertedWith('MG_UNAUTHORIZED');
  });

  it('Depositing funds twice for the same cycle should revert', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );

    await expect(
      contractee.Manager.depositFundsForNextCycle(agreementID)
    ).to.emit(Manager, 'FundsDeposited');

    await expect(
      contractee.Manager.depositFundsForNextCycle(agreementID)
    ).to.be.revertedWith('MG_FUNDS_ALREADY_SECURED');
  });
});
