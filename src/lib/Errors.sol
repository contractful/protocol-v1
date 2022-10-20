//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Errors {
  // *** Contract Specific Errors ***
  // Manager Contract 
  error MG_AGREEMENT_CLOSED(); // "The agreement is closed"
  error MG_AGREEMENT_INACTIVE(); // "The agreement is inactive. This might because the agreement has not been activated or because it has been closed"
  error MG_AGREEMENT_ACTIVE(); // "The agreement is active"
  error MG_UNAUTHORIZED(); // "msg.sender lacks the authorizations required"
}
  