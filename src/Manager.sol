// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./lib/IManager.sol";
import "./lib/Types.sol";
import "./lib/Roles.sol";
import "./lib/Errors.sol";
import "./Validator.sol";

/**
 * @title Manager
 * @author Contractful Labs
 * @notice Lets users create and manage contract work agreements
 */

pragma solidity ^0.8.0;

contract Manager is IManager, Validator {
  // General values. Only modifiable by Roles.GOVERNANCE
  uint128 public penalizationAmount;
  uint128 public challengeDuration;
  uint128 public establishmentFeeRate;
  uint256 internal accruedEstablishmentFee = 0;

  // These variables will be removed soon once the proxy implementation is updated.
  uint256 public agreementNonce = 1;
  mapping(address => uint256[]) public userAgreements;

  // agreement ID to agreement
  mapping(uint256 => Types.Agreement) public agreements;

  modifier whenActive(Types.Agreement storage agreement) {
    if (!agreement.state.active) {
      revert Errors.MG_AGREEMENT_INACTIVE();
    }
    _;
  }

  modifier whenPending(Types.Agreement storage agreement) {
    if (agreement.state.closed || agreement.state.active) {
      revert Errors.MG_AGREEMENT_NOT_PENDING();
    }
    _;
  }

  modifier onlyAuthorized(Types.Agreement storage agreement) {
    if (
      agreement.parameters.CONTRACTEE != msg.sender &&
      !hasRole(Roles.KEEPER_ROLE, msg.sender) &&
      !hasRole(Roles.GOVERNANCE_ROLE, msg.sender)
    ) {
      revert Errors.MG_UNAUTHORIZED();
    }
    _;
  }

  function initialize(uint128 challengeDuration_, address governance_) public initializer {
    initialize_();
    /* Both initializers below are called to comply with OpenZeppelin's
    recommendations even if in practice they don't do anything */
    __AccessControl_init();
    __Pausable_init_unchained();

    challengeDuration = challengeDuration_;

    if (governance_ == address(0)) {
      // Prevent setting governance_ to null account
      governance_ = _msgSender();
    }

    _grantRole(DEFAULT_ADMIN_ROLE, governance_);
    _grantRole(Roles.GOVERNANCE_ROLE, governance_);
    _setRoleAdmin(Roles.KEEPER_ROLE, Roles.GOVERNANCE_ROLE);
  }

  /**
   * @notice Creates a new agreement
   * @param params The parameters of the agreement
   * @dev The agreement default state is inactive, it needs to be activated by the contractor
   */
  function createAgreement(AgreementCreationParams calldata params) external whenNotPaused {
    assert(agreements[agreementNonce].parameters.AGREEMENT_ID == 0);

    if (params.contractor == address(0)) {
      revert Errors.MG_ADDRESS_ZERO();
    }

    if (params.contractor == msg.sender) {
      revert Errors.MG_CONTRACTOR_EQUALS_CONTRACTEE();
    }

    if (params.underlayingToken == address(0)) {
      revert Errors.MG_INVALID_TOKEN();
    }

    if (params.maturityDate <= block.timestamp) {
      revert Errors.MG_INVALID_MATURITY_DATE();
    }

    // Secure the funds for the first cycle
    SafeERC20.safeTransferFrom(IERC20(params.underlayingToken), msg.sender, address(this), params.paymentCycleAmount);

    agreements[agreementNonce].parameters = Types.AgreementParameters({
      AGREEMENT_ID: agreementNonce,
      ACCEPTANCE_DEADLINE: params.acceptanceDeadline,
      ACTIVATION_DATE: 0,
      MATURITY_DATE: params.maturityDate,
      PAYMENT_CYCLE_DURATION: params.paymentCycleDuration,
      PAYMENT_CYCLE_AMOUNT: params.paymentCycleAmount,
      ESTABLISHMENT_FEE_RATE: establishmentFeeRate,
      PENALIZATION_AMOUNT: penalizationAmount,
      UNDERLAYING_TOKEN: params.underlayingToken,
      CONTRACTOR: params.contractor,
      CONTRACTEE: msg.sender,
      DESCRIPTION_URI: params.descriptionURI
    });

    userAgreements[msg.sender].push(agreementNonce);
    userAgreements[params.contractor].push(agreementNonce);

    emit AgreementCreated(agreementNonce, params.contractor, msg.sender);
    agreementNonce++;
  }

  /**
   * @notice Activates an agreement
   * @param agreementID The ID of the agreement to activate
   * @dev The agreement needs to be created, inactive and the funds for the first cycle set
   */
  function activateAgreement(uint256 agreementID) external whenPending(agreements[agreementID]) {
    Types.Agreement storage agreement = agreements[agreementID];

    if (agreement.parameters.CONTRACTOR != msg.sender) {
      revert Errors.MG_UNAUTHORIZED();
    }

    if(block.timestamp > agreement.parameters.ACCEPTANCE_DEADLINE){
      revert Errors.MG_ACCEPTANCE_PERIOD_EXPIRED();
    }

    agreement.parameters.ACTIVATION_DATE = uint128(block.timestamp);
    agreement.state.active = true;

    userAgreements[msg.sender].push(agreementNonce);

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
  function migrateFunds(uint256 agreementID)
    external
    whenNotPaused
    whenActive(agreements[agreementID])
    onlyAuthorized(agreements[agreementID])
  {
    Types.Agreement storage agreement = agreements[agreementID];

    uint128 agreementDuration = agreement.parameters.MATURITY_DATE - agreement.parameters.ACTIVATION_DATE;
    uint128 migrations = agreementDuration / agreement.parameters.PAYMENT_CYCLE_DURATION;
    bool validMigrationPeriod = false;
    bool reminder = agreementDuration % agreement.parameters.PAYMENT_CYCLE_DURATION != 0;
    for (uint128 i = 0; i < migrations; i++) {
      uint128 migrationPeriod = agreement.parameters.ACTIVATION_DATE +
        (agreement.parameters.PAYMENT_CYCLE_DURATION * (i + 1));
      if (block.timestamp >= migrationPeriod) {
        if (block.timestamp <= migrationPeriod + challengeDuration) {
          validMigrationPeriod = true;
          break;
        }
      } else {
        break;
      }
    }
    if (!validMigrationPeriod) {
      if (reminder) {
        if (
          block.timestamp >= agreement.parameters.MATURITY_DATE &&
          block.timestamp <= agreement.parameters.MATURITY_DATE + challengeDuration
        ) {
          validMigrationPeriod = true;
        }
      }
    }

    if (!validMigrationPeriod) {
      revert Errors.MG_INVALID_MIGRATION_PERIOD();
    }

    uint128 normalizedPaymentAmount = (agreement.parameters.PAYMENT_CYCLE_AMOUNT * establishmentFeeRate) / 100;
    accruedEstablishmentFee += agreement.parameters.PAYMENT_CYCLE_AMOUNT - normalizedPaymentAmount;

    SafeERC20.safeTransfer(
      IERC20(agreement.parameters.UNDERLAYING_TOKEN),
      agreement.parameters.CONTRACTOR,
      normalizedPaymentAmount
    );

    emit FundsMigrated(agreementID, agreement.parameters.PAYMENT_CYCLE_AMOUNT);
  }

  function depositFundsForNextCycle(uint256 agreementID)
    external
    whenNotPaused
    whenActive(agreements[agreementID])
    onlyAuthorized(agreements[agreementID])
  {
    Types.Agreement storage agreement = agreements[agreementID];
    if (agreement.state.escrowedFunds != 0) {
      revert Errors.MG_FUNDS_ALREADY_SECURED();
    }

    agreement.state.escrowedFunds += agreement.parameters.PAYMENT_CYCLE_AMOUNT;
    SafeERC20.safeTransferFrom(
      IERC20(agreement.parameters.UNDERLAYING_TOKEN),
      agreement.parameters.CONTRACTEE,
      address(this),
      agreement.parameters.PAYMENT_CYCLE_AMOUNT
    );

    emit FundsDeposited(agreementID, agreement.parameters.PAYMENT_CYCLE_AMOUNT);
  }

  // View Methods

  /**
   * @notice Returns the parameters of an agreement
   * @param agreementID The ID of the agreement
   * @return acceptanceDeadline The timestamp the contractor can no longer accept the agreement
   * @return activationDate The timestamp when the agreement was activated
   * @return maturityDate The date when the agreement expires
   * @return paymentCycleDuration The duration of a payment cycle
   * @return paymentCycleAmount The amount of tokens to be released per payment cycle
   * @return establishmentFeeRate_ The rate of the establishment fee
   * @return penalizationAmount_ The amount of tokens that will be kept in case of a penalization
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
      uint128 acceptanceDeadline,
      uint128 activationDate,
      uint128 maturityDate,
      uint128 paymentCycleDuration,
      uint128 paymentCycleAmount,
      uint128 establishmentFeeRate_,
      uint128 penalizationAmount_,
      address underlayingToken,
      address contractor,
      address contractee,
      string memory descriptionURI
    )
  {
    Types.Agreement storage agreement = agreements[agreementID];
    return (
      agreement.parameters.ACCEPTANCE_DEADLINE,
      agreement.parameters.ACTIVATION_DATE,
      agreement.parameters.MATURITY_DATE,
      agreement.parameters.PAYMENT_CYCLE_DURATION,
      agreement.parameters.PAYMENT_CYCLE_AMOUNT,
      agreement.parameters.ESTABLISHMENT_FEE_RATE,
      agreement.parameters.PENALIZATION_AMOUNT,
      agreement.parameters.UNDERLAYING_TOKEN,
      agreement.parameters.CONTRACTOR,
      agreement.parameters.CONTRACTEE,
      agreement.parameters.DESCRIPTION_URI
    );
  }

  /**
   * @notice Returns the state of an agreement
   * @param agreementID The ID of the agreement
   * @param escrowedFunds The amount of funds escrowed in the agreement
   * @param active Whether the agreement is active
   * @param closed Whether the agreement is closed
   */
  function getAgreementState(uint256 agreementID)
    external
    view
    returns (
      uint128 escrowedFunds,
      bool active,
      bool closed
    )
  {
    Types.Agreement storage agreement = agreements[agreementID];
    return (agreement.state.escrowedFunds, agreement.state.active, agreement.state.closed);
  }

/**
* @notice Returns the user agreements
* @param user The address of the user
* @return agreementIDs The IDs of the agreements
 */
  function getUserAgreements(address user) view external returns (uint256[] memory) {
    return userAgreements[user];
  }

  // Managment methods. Only callable by Roles.GOVERNACE_ROLE

  /**
   * @notice Sets the challenge duration for all agreements
   * @param challengeDuration_ The new challenge duration
   */
  function setChallengeDuration(uint128 challengeDuration_) external onlyRole(Roles.GOVERNANCE_ROLE) {
    challengeDuration = challengeDuration_;
  }

  /**
   * @notice Set the establishment protocol fee rate
   * @param establishmentFeeRate_ The new establishment fee rate
   */
  function setEstablishmentFeeRate(uint128 establishmentFeeRate_) external onlyRole(Roles.GOVERNANCE_ROLE) {
    establishmentFeeRate = establishmentFeeRate_;
  }

  /**
   * @notice Set the penalization amount for the protocol
   * @param penalizationAmount_ The new penalization amount
   */
  function setPenalizationAmount(uint128 penalizationAmount_) external onlyRole(Roles.GOVERNANCE_ROLE) {
    establishmentFeeRate = penalizationAmount_;
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
    if (amount > accruedEstablishmentFee) {
      revert Errors.MG_AMOUNT_TOO_HIGH();
    }
    Types.Agreement storage agreement = agreements[agreementID];
    SafeERC20.safeTransfer(IERC20(agreement.parameters.UNDERLAYING_TOKEN), to, amount);
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
