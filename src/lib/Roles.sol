// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Roles {
  bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
  bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
}
