import {keccak256} from '@ethersproject/keccak256';
import {parseEther, toUtf8Bytes} from 'ethers/lib/utils';

export const AGREEMENT_ID = '0';
export const ONE_HOUR = 3600;
export const AGREEMENT_DURATION = ONE_HOUR * 24 * 30 * 6; // Six Months. The maturity date would then be the block.timestamp + AgreementDuration
export const CHALLENGE_DURATION = ONE_HOUR * 24 * 7; // 7 days
export const PAYMENT_CYCLE_DURATION = ONE_HOUR * 24 * 7 * 2; // 2 weeks
export const PAYMENT_CYCLE_AMOUNT = parseEther('1'); // payment amount for a successful payment cycle
export const ESTABLISHMENT_FEE_RATE = 0;
export const GOVERNANCE_ROLE = keccak256(toUtf8Bytes('GOVERNANCE_ROLE'));
export const KEEPER_ROLE = keccak256(toUtf8Bytes('KEEPER_ROLE'));
