import {BigNumber} from 'ethers';
import {deployments, ethers} from 'hardhat';
import {Manager} from '../../typechain';
import {setupFixture} from '../utils';
import {ONE_HOUR} from '../utils/constants';
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
      testContractee,
      agreementID: agreementIDTemp,
      testUser1,
    } = await setupTestContracts(deployer, mocks, users);

    Manager = deployedManager;
    contractee = testContractee;
    contractor = testContractor;
    agreementID = agreementIDTemp; // agreementIDTemp == agreementID
    user1 = testUser1;
  });

  it('Migrating funds for an inactive agreement should revert', async function () {
    await expect(
      contractee.Manager.migrateFunds(agreementID)
    ).to.be.revertedWith('MG_NOT_ONGOING');
  });

  it('Migrating funds where the msg.sender is not the contractee, keeper or governance should revert', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );

    await expect(user1.Manager.migrateFunds(agreementID)).to.be.revertedWith(
      'MG_UNAUTHORIZED'
    );
  });

  it('Migrating funds when it is not the migration period should revert', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );

    await expect(
      contractee.Manager.migrateFunds(agreementID)
    ).to.be.revertedWith('MG_INVALID_MIGRATION_PERIOD');
  });

  it('Migrating funds when the agreement is active, on a migration period as an authorized user should be successful', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );

    const agreementParams = await Manager.getAgreementParameters(agreementID);

    // fast forward to the migration period
    await ethers.provider.send('evm_increaseTime', [
      // One day because that begging date is one day in the future
      ONE_HOUR * 24 + agreementParams.paymentCycleDuration.toNumber() * 2, // 2 cycles
    ]);
    await ethers.provider.send('evm_mine', []);

    await expect(contractee.Manager.migrateFunds(agreementID)).to.emit(
      Manager,
      'FundsMigrated'
    );
  });
});
