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

describe('Manager - cancel agreement', async function () {
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

  it('Canceling an agreement when it is inactive should work', async function () {
    await expect(contractee.Manager.cancelAgreement(agreementID)).to.emit(
      contractee.Manager,
      'AgreementCancelled'
    );
  });
});
