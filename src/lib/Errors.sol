//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Errors {
  // *** Contract Specific Errors ***
  // Manager Contract
  error MG_NOT_ONGOING(); // "The agreement is not ongoing"
  error MG_AGREEMENT_NOT_PENDING(); // "The agreement is not pending. It can be active or closed"
  error MG_UNAUTHORIZED(); // "msg.sender lacks the authorizations required"
  error MG_CONTRACTOR_EQUALS_CONTRACTEE(); // "The contractor and the contractee cannot be the same"
  error MG_INVALID_MATURITY_DATE(); // "The maturity date must be in the future"
  error MG_INVALID_TOKEN(); // "The token is not an accepted token. It probably is a zero address"
  error MG_ADDRESS_ZERO(); // "The address cannot be zero"
  error MG_INVALID_MIGRATION_PERIOD(); // "The migration period is not valid"
  error MG_AMOUNT_TOO_HIGH(); // "The amount is too high"
  error MG_FUNDS_ALREADY_SECURED(); // "The funds are already secured"
  error MG_INVALID_PERCENTAGES(); // "The percentages are not valid. For the moment they must sum up to 100"
  error MG_AGREEMENT_ALREADY_CHALLENGED(); // "The agreement is already challenged"
  error MG_PAST_BEGINNING_DATE(); // "The date is in the past"
}
