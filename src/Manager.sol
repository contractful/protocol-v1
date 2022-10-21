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

  // agreement ID to agreement
  mapping(uint256 => Types.Agreement) public agreements;

  modifier whenActive(Types.Agreement storage agreement) {
    if(!agreement.active) {
      revert Errors.MG_AGREEMENT_INACTIVE();
    }
    _;
  }

  modifier whenPending(Types.Agreement storage agreement) {
    if(agreement.closed || agreement.active) {
      revert Errors.MG_AGREEMENT_NOT_PENDING();
    }
    _;
  }

  function initialize(uint128 _challengeDuration, address _governance) public initializer {
    /* both initializers below are called to comply with OpenZeppelin's
    recommendations even if in practice they don't do anything */
    __AccessControl_init();
    __Pausable_init_unchained();

    challengeDuration = _challengeDuration;

    if(_governance == address(0)) {
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

    if(params.contractor == address(0) || params.contractee == address(0)) {
      revert Errors.MG_ADDRESS_ZERO();
    }

    if(params.contractor == params.contractee) {
      revert Errors.MG_CONTRACTOR_EQUALS_CONTRACTEE();
    }

    if(params.underlayingToken == address(0)) {
      revert Errors.MG_INVALID_TOKEN();
    }

    if(params.maturityDate <= block.timestamp) {
      revert Errors.MG_INVALID_MATURITY_DATE();
    }

    agreements[agreementNonce] = Types.Agreement({
      AGREEMENT_ID: agreementNonce,
      ACTIVATION_DATE: 0,
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
   * @param agreementID The ID of the agreement to activate
   * @dev The agreement needs to be created, inactive and the funds for the first cycle set
   */
  function activateAgreement(uint256 agreementID) external whenPending(agreements[agreementID]) {
    Types.Agreement storage agreement = agreements[agreementID];

    if(agreement.CONTRACTOR != msg.sender) {
      revert Errors.MG_UNAUTHORIZED();
    }

    agreement.ACTIVATION_DATE = uint128(block.timestamp);
    agreement.active = true;

    emit AgreementActivated(agreementID);
  }

  /**
   * @notice Releases the funds for the current payment cycle
   * @param agreementID The ID of the agreement to release the funds for
   * @dev Only the keeper or contractee can call this function
   * @dev A for loop is used to calculate the migration periods instead of storing them on chain to reduce gas costs
   * @dev To reduce gas costs, the migration periods are calculated inside the function, instead of calling calculateMigrationPeriods
   * @dev If there is a remainder, the last migration period will be shorter than the others and fall on the maturity date
   */
  function migrateFunds(uint256 agreementID) external whenNotPaused whenActive(agreements[agreementID]) {
    Types.Agreement storage agreement = agreements[agreementID];
    if(
      agreement.CONTRACTEE != msg.sender &&
      !hasRole(Roles.KEEPER_ROLE, msg.sender) &&
      !hasRole(Roles.GOVERNANCE_ROLE, msg.sender)
    ) {
      revert Errors.MG_UNAUTHORIZED();
    }

    uint128 agreementDuration = agreement.MATURITY_DATE - agreement.ACTIVATION_DATE;
    uint128 migrations = agreementDuration / agreement.PAYMENT_CYCLE_DURATION;
    bool validMigrationPeriod = false;
    for (uint128 i = 0; i < migrations; i++) {
      uint128 migrationPeriod = agreement.ACTIVATION_DATE + (agreement.PAYMENT_CYCLE_DURATION * (i + 1));
      if(block.timestamp >= migrationPeriod) {
        if(block.timestamp <= migrationPeriod + challengeDuration) {
          validMigrationPeriod = true;
          break;
        }
      } else {
        break;
      }
    }
    if(!validMigrationPeriod) {
      bool reminder = agreementDuration % agreement.PAYMENT_CYCLE_DURATION != 0;
      if(reminder) {
        if(
          block.timestamp >= agreement.MATURITY_DATE && block.timestamp <= agreement.MATURITY_DATE + challengeDuration
        ) {
          validMigrationPeriod = true;
        }
      }
    }

    if(!validMigrationPeriod) {
      revert Errors.MG_INVALID_MIGRATION_PERIOD();
    }

    SafeERC20.safeTransfer(IERC20(agreement.UNDERLAYING_TOKEN), agreement.CONTRACTOR, agreement.PAYMENT_CYCLE_AMOUNT);

    emit FundsMigrated(agreementID, agreement.PAYMENT_CYCLE_AMOUNT);
  }

  // View Methods

  /**
   * @notice Calculates the migration periods for an agreement
   * @param agreementDuration The duration of the agreement
   * @param paymentCycleDuration The duration of the payment cycle
   * @return migrationPeriods The migration periods for the agreement
   * @dev If there is a remainder, the last migration period will be shorter than the others and fall on the maturity date
   * @dev the return value is a list of the starting migration periods. To actualy calculate the period you need to add the challenge duration
   */
  function calculateMigrationPeriods(uint128 agreementDuration, uint128 paymentCycleDuration)
    public
    view
    returns (uint128[] memory migrationPeriods)
  {
    Types.Agreement storage agreement = agreements[agreementNonce];

    uint128 migrations = agreementDuration / paymentCycleDuration;
    bool reminder = agreementDuration % paymentCycleDuration != 0;

    for (uint128 i = 0; i < migrations; i++) {
      migrationPeriods[i] = agreement.ACTIVATION_DATE + (paymentCycleDuration * i + 1);
    }
    if(reminder) {
      migrationPeriods[migrations] = agreement.MATURITY_DATE;
    }
  }

  /**
   * @notice Returns the parameters of an agreement
   * @param agreementID The ID of the agreement
   * @return activationDate The timestamp when the agreement was activated
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
      uint128 activationDate,
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
      agreement.ACTIVATION_DATE,
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
