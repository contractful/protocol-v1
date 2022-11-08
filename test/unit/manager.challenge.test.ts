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

describe('Manager - challenge agreement', async function () {
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

  it('Challenging an agreement that is not ongoing should revert', async function () {
    await expect(
      contractor.Manager.challengeAgreement(agreementID)
    ).to.be.revertedWith('MG_NOT_ONGOING');
  });

  it('Challenging an ongoing agreement should go through', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      contractor.Manager,
      'AgreementActivated'
    );

    await expect(contractee.Manager.challengeAgreement(agreementID)).to.emit(
      contractee.Manager,
      'AgreementChallenged'
    );
  });

  it('Challenging an agreement successfully should set the agreement to challenged', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      contractor.Manager,
      'AgreementActivated'
    );

    await expect(contractee.Manager.challengeAgreement(agreementID)).to.emit(
      contractee.Manager,
      'AgreementChallenged'
    );

    const agreement = await Manager.getAgreementState(agreementID);
    expect(agreement.challenged).to.be.true;
  });
});
