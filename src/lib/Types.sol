// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

library Types {
    struct Agreement {
        uint256 AGREEMENT_ID;
        uint128 MATURITY_DATE;
        uint128 PAYMENT_CYCLE_DURATION;
        uint128 PAYMENT_CYCLE_AMOUNT;
        address UNDERLAYING_TOKEN;
        address CONTRACTOR;
        address CONTRACTEE;
        bool active;
        bool closed;
    }
}
