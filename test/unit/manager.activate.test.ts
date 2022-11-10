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

describe('Manager - activateAgreement', async function () {
  let contractee: User, contractor: User;
  let Manager: Manager;
  let agreementID: BigNumber;

  beforeEach(async function () {
    const {deployer, mocks, users} = await setup();
    const {
      deployedManager,
      testContractor,
      testContractee,
      agreementID: agreementIDTemp,
    } = await setupTestContracts(deployer, mocks, users);

    Manager = deployedManager;
    contractee = testContractee;
    contractor = testContractor;
    agreementID = agreementIDTemp; // agreementIDTemp == agreementID
  });

  it('Activating an agreement that is not pending should revert', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );
    await expect(
      contractor.Manager.activateAgreement(agreementID)
    ).to.be.revertedWith('MG_AGREEMENT_NOT_PENDING');
  });

  it('Activating an agreement after the beginning date should revert', async function () {
    await ethers.provider.send('evm_increaseTime', [ONE_HOUR * 25]);
    await ethers.provider.send('evm_mine', []);

    await expect(
      contractor.Manager.activateAgreement(agreementID)
    ).to.be.revertedWith('MG_PAST_BEGINNING_DATE');
  });

  it('Activating an agreement for which msg.sender is not the contractor should revert', async function () {
    await expect(
      contractee.Manager.activateAgreement(agreementID)
    ).to.be.revertedWith('MG_UNAUTHORIZED');
  });

  it('Activating an agreement with the right params and state should be successful', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      Manager,
      'AgreementActivated'
    );
  });
});
