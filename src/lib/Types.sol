// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

library Types {
  /* The protocol's fee rate and penalization amount are stored in each agreement so if they changes, they will not affect
 previous agreements */
  struct AgreementParameters {
    uint256 AGREEMENT_ID;
    uint128 BEGINNING_DATE;
    uint128 MATURITY_DATE;
    uint128 PAYMENT_CYCLE_DURATION;
    uint128 PAYMENT_CYCLE_AMOUNT;
    uint128 ESTABLISHMENT_FEE_RATE;
    uint128 PENALIZATION_AMOUNT;
    address UNDERLAYING_TOKEN;
    address CONTRACTOR;
    address CONTRACTEE;
    string DESCRIPTION_URI;
  }

  struct AgreementState {
    uint128 escrowedFunds;
    bool closed;
    bool challenged;
    bool active;
  }

  struct Agreement {
    AgreementParameters parameters;
    AgreementState state;
  }
}
