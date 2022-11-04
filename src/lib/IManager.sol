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
  event FundsMigrated(uint256 agreement, uint128 amount);

  /**
   * @notice Emitted after funds are deposited for the upcoming cycle
   * @param agreement The ID of the agreement
   * @param amount The amount of tokens that were deposited
   */
  event FundsDeposited(uint256 agreement, uint128 amount);

  // VIEW Methods

  /**
   * @notice Returns the parameters of an agreement
   * @param agreementID The ID of the agreement
   * @return beginningDate The beginning date of the agreement
   * @return acceptanceDeadline The timestamp the contractor can no longer accept the agreement
   * @return maturityDate The date when the agreement expires
   * @return paymentCycleDuration The duration of a payment cycle
   * @return paymentCycleAmount The amount of tokens to be released per payment cycle
   * @return establishmentFeeRate The rate of the establishment fee
   * @return penalizationAmount The amount of tokens that will be kept in case of a penalization
   * @return underlayingToken The address of the token used for the agreement
   * @return contractor The address of the contractor
   * @return contractee The address of the contractee
   * @return descriptionURI The URI of the agreement description
   * @dev an agreement can be not active because it has not been activated or because it is closed
   */
  function getAgreementParameters(uint256 agreementID)
    external
    view
    returns (
      uint128 beginningDate,
      uint128 acceptanceDeadline,
      uint128 maturityDate,
      uint128 paymentCycleDuration,
      uint128 paymentCycleAmount,
      uint128 establishmentFeeRate,
      uint128 penalizationAmount,
      address underlayingToken,
      address contractor,
      address contractee,
      string memory descriptionURI
    );

  // MUTATIVE Methods

  struct AgreementCreationParams {
    uint128 beginningDate;
    uint128 acceptanceDeadline;
    uint128 maturityDate;
    uint128 paymentCycleDuration;
    uint128 paymentCycleAmount;
    address underlayingToken;
    address contractor;
    string descriptionURI;
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
