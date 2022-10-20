import {ethers} from 'ethers';
import {deployments} from 'hardhat';
import {Manager} from '../../typechain';
import {setupFixture} from '../utils';
import {AgreementCreationParams, User} from '../utils/types';
import {expect} from './helpers/chai-setup';
import {setupTestContracts} from './utils';

const setup = deployments.createFixture(async () => {
  return setupFixture('all');
});

describe('Manager - createAgreement', async function () {
  let contractee: User, contractor: User;
  let Manager: Manager;
  let agreementParams: AgreementCreationParams;

  beforeEach(async function () {
    const {deployer, mocks, users} = await setup();
    const {deployedManager, testContractor, testContractee, agreementID} =
      await setupTestContracts(deployer, mocks, users);

    Manager = deployedManager;
    contractee = testContractee;
    contractor = testContractor;

    agreementParams = await Manager.getAgreementParameters(agreementID);
  });

  it('Creating an agreement with an address zero for either the contractee or contractor should revert', async function () {
    const modifiedAgreementParams = {
      ...agreementParams,
      contractee: ethers.constants.AddressZero,
    };
    await expect(
      Manager.createAgreement(modifiedAgreementParams)
    ).to.be.revertedWith('MG_ADDRESS_ZERO');
  });

  it('Creating an agreement with the same addresses for the parameters: contractee, contractor should revert', async function () {
    const modifiedAgreementParams = {
      ...agreementParams,
      contractee: contractor.address,
    };
    await expect(
      Manager.createAgreement(modifiedAgreementParams)
    ).to.be.revertedWith('MG_CONTRACTOR_EQUALS_CONTRACTEE');
  });

  it('Creating an agreement with a past maturity date should revert', async function () {
    const modifiedAgreementParams = {
      ...agreementParams,
      maturityDate: 1,
    };
    await expect(
      Manager.createAgreement(modifiedAgreementParams)
    ).to.be.revertedWith('MG_INVALID_MATURITY_DATE');
  });

  // we don't test to create a valid agreement because it was successful in the setup contract beforeEach call
});
