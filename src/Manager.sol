// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./lib/IManager.sol";
import "./lib/Types.sol";
import "./lib/Roles.sol";
import "./lib/Errors.sol";

/**
 * @title IManager
 * @author Contractful Labs
 * @notice Lets users create and manage contract work agreements
 */

pragma solidity ^0.8.0;

contract Manager is IManager, AccessControlUpgradeable, PausableUpgradeable {
  // General values. Only modifiable by Roles.GOVERNANCE
  uint128 public challengeDuration;
  uint128 public establishmentFeeRate;
  uint256 public agreementNonce = 1;

  // agreement hash to agreement
  mapping(uint256 => Types.Agreement) public agreements;

  modifier whenActive(Types.Agreement storage agreement) {
    if (!agreement.active) {
      revert Errors.MG_AGREEMENT_INACTIVE();
    }
    _;
  }

  modifier whenInactive(Types.Agreement storage agreement) {
    if (agreement.closed || agreement.active) {
      revert Errors.MG_AGREEMENT_ACTIVE();
    }
    _;
  }

  function initialize(uint128 _challengeDuration, address _governance) public initializer {
    /* both initializers below are called to comply with OpenZeppelin's
    recommendations even if in practice they don't do anything */
    __AccessControl_init();
    __Pausable_init_unchained();

    challengeDuration = _challengeDuration;

    if (_governance == address(0)) {
      // Prevent setting _governance to null account
      _governance = _msgSender();
    }

    _grantRole(DEFAULT_ADMIN_ROLE, _governance);
    _grantRole(Roles.GOVERNANCE_ROLE, _governance);
    _setRoleAdmin(Roles.KEEPER_ROLE, Roles.GOVERNANCE_ROLE);
  }

  /**
   * @notice Creates a new agreement
   * @param params The parameters of the agreement
   * @dev The agreement default state is inactive, it needs to be activated by the contractor
   */
  function createAgreement(AgreementCreationParams calldata params) external whenNotPaused {
    assert(agreements[agreementNonce].AGREEMENT_ID == 0);

    agreements[agreementNonce] = Types.Agreement({
      AGREEMENT_ID: agreementNonce,
      MATURITY_DATE: params.maturityDate,
      PAYMENT_CYCLE_DURATION: params.paymentCycleDuration,
      PAYMENT_CYCLE_AMOUNT: params.paymentCycleAmount,
      UNDERLAYING_TOKEN: params.underlayingToken,
      CONTRACTOR: params.contractor,
      CONTRACTEE: params.contractee,
      active: false,
      closed: false
    });
    emit AgreementCreated(agreementNonce, params.contractor, params.contractee);
    agreementNonce++;
  }

  /**
   * @notice Activates an agreement
   * @param agreementID The hash of the agreement to activate
   * @dev The agreement needs to be created, inactive and the funds for the first cycle set
   */
  function activateAgreement(uint256 agreementID) external whenInactive(agreements[agreementID]) {
    Types.Agreement storage agreement = agreements[agreementID];

    if (agreement.closed == true) {
      revert Errors.MG_AGREEMENT_CLOSED();
    }
    if (agreement.active != false) {
      revert Errors.MG_AGREEMENT_ACTIVE();
    }
    if (agreement.CONTRACTOR != msg.sender) {
      revert Errors.MG_UNAUTHORIZED();
    }

    agreement.active = true;

    emit AgreementActivated(agreementID);
  }

  /**
   * @notice Releases the funds for the current payment cycle
   * @param agreementID The hash of the agreement to release the funds for
   * @dev Only the keeper or contractee can call this function
   */
  function migrateFunds(uint256 agreementID) external whenNotPaused whenActive(agreements[agreementID]) {
    Types.Agreement storage agreement = agreements[agreementID];
    if (agreement.CONTRACTEE != msg.sender && !hasRole(Roles.KEEPER_ROLE, msg.sender) && !hasRole(Roles.GOVERNANCE_ROLE, msg.sender)) {
      revert Errors.MG_UNAUTHORIZED();
    }
    SafeERC20.safeTransfer(IERC20(agreement.UNDERLAYING_TOKEN), agreement.CONTRACTOR, agreement.PAYMENT_CYCLE_AMOUNT);
  }

  // View Methods

  /**
   * @notice Returns the parameters of an agreement
   * @param agreementID The ID of the agreement
   * @return maturityDate The date when the agreement expires
   * @return paymentCycleDuration The duration of a payment cycle
   * @return paymentCycleAmount The amount of tokens to be released per payment cycle
   * @return underlayingToken The address of the token used for the agreement
   * @return contractor The address of the contractor
   * @return contractee The address of the contractee
   * @return active Whether the agreement is active
   * @return closed Whether the agreement is closed
   * @dev an agreement can be not active because it has not been activated or because it is closed
   */
  function getAgreementParameters(uint256 agreementID)
    external
    view
    returns (
      uint128 maturityDate,
      uint128 paymentCycleDuration,
      uint128 paymentCycleAmount,
      address underlayingToken,
      address contractor,
      address contractee,
      bool active,
      bool closed
    )
  {
    Types.Agreement storage agreement = agreements[agreementID];
    return (
      agreement.MATURITY_DATE,
      agreement.PAYMENT_CYCLE_DURATION,
      agreement.PAYMENT_CYCLE_AMOUNT,
      agreement.UNDERLAYING_TOKEN,
      agreement.CONTRACTOR,
      agreement.CONTRACTEE,
      agreement.active,
      agreement.closed
    );
  }

  // Managment methods. Only callable by Roles.GOVERNACE_ROLE

  /**
   * @notice Sets the challenge duration for all agreements
   * @param _challengeDuration The new challenge duration
   */
  function setChallengeDuration(uint128 _challengeDuration) external onlyRole(Roles.GOVERNANCE_ROLE) {
    challengeDuration = _challengeDuration;
  }

  /**
   * @notice Set the establishment protocol fee rate
   **/
  function setEstablishmentFeeRate(uint128 _establishmentFeeRate) external onlyRole(Roles.GOVERNANCE_ROLE) {
    establishmentFeeRate = _establishmentFeeRate;
  }

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
  ) external onlyRole(Roles.GOVERNANCE_ROLE) {
    Types.Agreement storage agreement = agreements[agreementID];
    SafeERC20.safeTransfer(IERC20(agreement.UNDERLAYING_TOKEN), to, amount);
  }

  /**
   * @notice Stops all actions on all agreements
   **/
  function freezeAgreements() external onlyRole(Roles.GOVERNANCE_ROLE) {
    _pause();
  }

  /**
   * @notice Cancel a freeze, makes actions available again on all agreements
   **/
  function unfreezeAgreements() external onlyRole(Roles.GOVERNANCE_ROLE) {
    _unpause();
  }
}
