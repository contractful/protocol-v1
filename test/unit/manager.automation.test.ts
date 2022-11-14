import {BigNumber} from 'ethers';
import {deployments, ethers} from 'hardhat';
import {Manager} from '../../typechain';
import {ONE_HOUR, PAYMENT_CYCLE_AMOUNT} from '../utils/constants';
import {setupFixture} from '../utils';
import {AgreementCreationParams, User} from '../utils/types';
import {assert, expect} from './helpers/chai-setup';
import {setupTestContracts} from './utils';

const setup = deployments.createFixture(async () => {
    return setupFixture('all');
  });

describe('Manager - chainlink automation', async function () {
    let contractee: User, contractor: User;
    let Manager: Manager;
    let agreementParams: AgreementCreationParams;
    let agreementID: BigNumber;
    let user1: User;
  
    beforeEach(async function () {
      const {deployer, mocks, users} = await setup();
      const {
        deployedManager,
        testContractor,
        testContractee,
        agreementID: tempAgreementID,
        testUser1
      } = await setupTestContracts(deployer, mocks, users);
  
      Manager = deployedManager;
      contractee = testContractee;
      contractor = testContractor;
      agreementID = tempAgreementID;
      user1 = testUser1;
      agreementParams = await Manager.getAgreementParameters(agreementID);
    });

    describe("checkUpkeep", () => {
        it("If agreement isn't ongoing, revert", async () => {

            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            await expect(Manager.callStatic.checkUpkeep(checkData)).to.be.revertedWith('MG_NOT_ONGOING');
        });

        it("If agreement is activated but not in migration period, revert", async () => {

            await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
                Manager,
                'AgreementActivated'
              );
            
            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            await expect(Manager.callStatic.checkUpkeep(checkData)).to.be.revertedWith('MG_INVALID_MIGRATION_PERIOD');
        });

        it("For external account like chainlink - returns upkeepNeeded & performData correctly for activated agreement in migration period", async () => {
            await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
                Manager,
                'AgreementActivated'
              );
            
            const agreementParams = await user1.Manager.getAgreementParameters(agreementID);

            // fast forward to the migration period
            await ethers.provider.send('evm_increaseTime', [
            // One day because that begging date is one day in the future
            ONE_HOUR * 24 + agreementParams.paymentCycleDuration.toNumber() * 2, // 2 cycles
            ]);
            await ethers.provider.send('evm_mine', []);

            
            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            const { upkeepNeeded, performData } = await user1.Manager.callStatic.checkUpkeep(checkData);

            assert(upkeepNeeded);
            assert(performData);
        });

        it("Returns upkeepNeeded & performData correctly for activated agreement in migration period", async () => {
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

            
            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            const { upkeepNeeded, performData } = await Manager.callStatic.checkUpkeep(checkData);

            assert(upkeepNeeded);
            assert(performData);
        });
    });

    describe("performUpkeep", () => {
        it("If agreement isn't ongoing, revert", async () => {

            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            await expect(Manager.callStatic.checkUpkeep(checkData)).to.be.revertedWith('MG_NOT_ONGOING');
        });

        it("If agreement is activated but not in migration period, revert", async () => {

            await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
                Manager,
                'AgreementActivated'
              );
            
            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            await expect(Manager.callStatic.checkUpkeep(checkData)).to.be.revertedWith('MG_INVALID_MIGRATION_PERIOD');
        });

        it("Triggers auto payments for activated agreement in migration period should be successful", async () => {

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

            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            const { upkeepNeeded, performData } = await Manager.callStatic.checkUpkeep(checkData);

            assert(upkeepNeeded);
            assert(performData);

            if (upkeepNeeded) {

                const txResponse = await Manager.performUpkeep(
                    performData
                );

                const txReceipt = await txResponse.wait(1);
                assert(txReceipt);

                if (txReceipt.events){
                    const agreementIDnew = txReceipt.events[0].args!.agreement;
                    const paymentCycleAmountnew = txReceipt.events[0].args!.amount;
                    assert (agreementIDnew, agreementID.toString());
                    assert (paymentCycleAmountnew, PAYMENT_CYCLE_AMOUNT.toString());
                }
            }
        });

        it("For external user like chainlink - Triggers auto payments for activated agreement in migration period should be successful", async () => {

            await expect(contractor.Manager.activateAgreement(agreementID)).to.emit(
                Manager,
                'AgreementActivated'
              );
            
            const agreementParams = await user1.Manager.getAgreementParameters(agreementID);

            // fast forward to the migration period
            await ethers.provider.send('evm_increaseTime', [
            // One day because that begging date is one day in the future
            ONE_HOUR * 24 + agreementParams.paymentCycleDuration.toNumber() * 2, // 2 cycles
            ]);
            await ethers.provider.send('evm_mine', []);

            const checkData = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("")
            );
            const { upkeepNeeded, performData } = await user1.Manager.callStatic.checkUpkeep(checkData);

            assert(upkeepNeeded);
            assert(performData);

            if (upkeepNeeded) {

                const txResponse = await user1.Manager.performUpkeep(
                    performData
                );

                const txReceipt = await txResponse.wait(1);
                assert(txReceipt);

                if (txReceipt.events){
                    const agreementIDnew = txReceipt.events[0].args!.agreement;
                    const paymentCycleAmountnew = txReceipt.events[0].args!.amount;
                    assert (agreementIDnew, agreementID.toString());
                    assert (paymentCycleAmountnew, PAYMENT_CYCLE_AMOUNT.toString());
                }
            }
        });
    });
});