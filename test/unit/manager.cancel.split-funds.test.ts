import {BigNumber} from 'ethers';
import {deployments, ethers} from 'hardhat';
import {Manager} from '../../typechain';
import {setupFixture} from '../utils';
import {User} from '../utils/types';
import {PAYMENT_CYCLE_DURATION} from './../utils/constants';
import {expect} from './helpers/chai-setup';
import {setupTestContracts} from './utils';

const setup = deployments.createFixture(async () => {
  return setupFixture('all');
});

describe('Manager - split funds', async function () {
  let governance: User, contractee: User, contractor: User;
  let Manager: Manager;
  let agreementID: BigNumber;

  beforeEach(async function () {
    const {deployer, mocks, users} = await setup();
    const {
      deployedManager,
      governance: testGovernance,
      testContractor,
      testContractee,
      agreementID: agreementIDTemp,
    } = await setupTestContracts(deployer, mocks, users);

    Manager = deployedManager;
    governance = testGovernance;
    contractee = testContractee;
    contractor = testContractor;
    agreementID = agreementIDTemp; // agreementIDTemp == agreementID
  });

  it.only('Splitting the funds successfully should increase the balances of the parties by the correct percentages', async function () {
    await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
      contractee.Manager,
      'AgreementActivated'
    );

    await ethers.provider.send('evm_increaseTime', [PAYMENT_CYCLE_DURATION]);
    await ethers.provider.send('evm_mine', []);

    await expect(governance.Manager.splitFunds(agreementID, 100, 0)).to.emit(
      governance.Manager,
      'FundsSplitted'
    );

    // Todo - actually check balances
  });
});
