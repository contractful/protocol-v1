// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

/**
 * @title IManager
 * @author Contractful Labs
 * @notice Lets users create and manage contract work agreements
 */

interface IManager {
  // EVENTS

  /**
   * @notice Emitted after a event was creted
   * @param agreementID The ID of the agreement
   * @param contractor The address of the contractor
   * @param contractee The address of the contractee
   **/
  event AgreementCreated(uint256 agreementID, address contractor, address contractee);

  /**
   * @notice Emitted after a agreement was activated
   * @param agreementID The ID of the agreement
   **/
  event AgreementActivated(uint256 agreementID);

  /**
   * @notice Emitted after funds were migrated
   * @param agreement The ID of the agreement
   * @param amount The amount of tokens that were migrated
   **/
  event FundsMigrated(uint256 agreement, uint256 amount);

  // VIEW Methods

  // MUTATIVE Methods

  struct AgreementCreationParams {
    uint128 maturityDate;
    uint128 paymentCycleDuration;
    uint128 paymentCycleAmount;
    address underlayingToken;
    address contractor;
    address contractee;
  }

  /**
   * @notice Creates a new agreement
   * @param params The parameters of the agreement
   */
  function createAgreement(AgreementCreationParams calldata params) external;

  /**
   * @notice Activates an agreement
   * @param agreementID The ID of the agreement to activate
   */
  function activateAgreement(uint256 agreementID) external;

  /**
   * @notice Set the establishment protocol fee rate
   **/
  function setEstablishmentFeeRate(uint128 establishmentFeeRate) external;

  /**
   * @notice Releases the funds for the current payment cycle
   * @param agreementID The ID of the agreement to release the funds for
   */
  function migrateFunds(uint256 agreementID) external;

  /**
   * @notice Withdraws protocol fees to a target address
   * @param agreementID The identifier of the agreement 
   * @param amount The amount of tokens claimed
   * @param to The address receiving the fees
   **/
  function claimProtocolFees(
    uint256 agreementID,
    uint128 amount,
    address to
  ) external;

  /**
   * @notice Stops all actions on all agreements 
   **/
  function freezeAgreements() external;

  /**
   * @notice Cancel a freeze, makes actions available again on all agreements 
   **/
  function unfreezeAgreements() external;
}
