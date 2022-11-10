// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

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

contract Manager is IManager, Validator, AutomationCompatibleInterface {
  // General values. Only modifiable by Roles.GOVERNANCE
  uint128 public penalizationAmount;
  uint128 public challengeDuration;
  uint128 public establishmentFeeRate;
  uint256 internal accruedEstablishmentFee = 0;

  // These variables will be removed soon once the proxy implementation is updated.
  uint256 public agreementNonce = 1;
  uint256[] internal agreementIDs;

  mapping(address => uint256[]) public userAgreements;

  // agreement ID to agreement
  mapping(uint256 => Types.Agreement) public agreements;

  modifier whenPending(Types.Agreement storage agreement) {
    if (agreement.state.closed || agreement.state.active) {
      revert Errors.MG_AGREEMENT_NOT_PENDING();
    }
    _;
  }

  modifier whenOngoing(Types.Agreement storage agreement) {
    if (!agreement.state.active || agreement.state.closed || agreement.state.challenged) {
      revert Errors.MG_NOT_ONGOING();
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
    agreements[agreementNonce].state.escrowedFunds = params.paymentCycleAmount;

    agreements[agreementNonce].parameters = Types.AgreementParameters({
      AGREEMENT_ID: agreementNonce,
      BEGINNING_DATE: params.beginningDate,
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
    agreementIDs.push(agreementNonce);

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

    if (block.timestamp > agreement.parameters.BEGINNING_DATE) {
      revert Errors.MG_PAST_BEGINNING_DATE();
    }

    agreement.state.active = true;

    userAgreements[msg.sender].push(agreementNonce);

    emit AgreementActivated(agreementID);
  }

  function checkFundsMigration(uint256 agreementID)
    internal
    view
    whenNotPaused
    whenOngoing(agreements[agreementID])
    onlyAuthorized(agreements[agreementID])
    returns (bool isValidMigrationPeriod)
  {
    Types.Agreement storage agreement = agreements[agreementID];

    uint128 agreementDuration = agreement.parameters.MATURITY_DATE - agreement.parameters.BEGINNING_DATE;
    uint128 migrations = agreementDuration / agreement.parameters.PAYMENT_CYCLE_DURATION;
    bool validMigrationPeriod = false;
    bool reminder = agreementDuration % agreement.parameters.PAYMENT_CYCLE_DURATION != 0;
    for (uint128 i = 0; i < migrations; i++) {
      uint128 migrationPeriod = agreement.parameters.BEGINNING_DATE +
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
    return validMigrationPeriod;
  }

  /**
   * @notice Releases the funds for the current payment cycle
   * @param agreementID The ID of the agreement to release the funds for
   * @dev Only the keeper or contractee can call this function
   * @dev A for loop is used to calculate the migration periods instead of storing them on chain to reduce gas costs
   * @dev If there is a remainder, the last migration period will be shorter than the others and fall on the maturity date
   */

  //TODO: should this be kept internal since we have keepers?
  function migrateFunds(uint256 agreementID)
    internal
    whenNotPaused
    whenActive(agreements[agreementID])
    onlyAuthorized(agreements[agreementID])
  {
    Types.Agreement storage agreement = agreements[agreementID];

    agreement.state.escrowedFunds -= agreement.parameters.PAYMENT_CYCLE_AMOUNT;
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
    internal
    whenNotPaused
    whenOngoing(agreements[agreementID])
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

  function checkUpkeep(bytes calldata)
    external
    view
    override
    whenNotPaused
    returns (bool upkeepNeeded, bytes memory performData)
  {
    uint256[] memory agreementsToMigrateFunds = new uint256[](agreementIDs.length);
    uint256 count = 0;

    for (uint256 idx = 0; idx < agreementIDs.length; idx++){
      if (checkFundsMigration(agreementIDs[idx])) {
        upkeepNeeded = true;
        agreementsToMigrateFunds[count] = agreementIDs[idx];
        count++;
      }
    }
    performData = abi.encode(agreementsToMigrateFunds);
    return (upkeepNeeded, performData);
  }

  function performUpkeep(bytes calldata performData)
    external
    override 
    whenNotPaused 
  {
    uint256[] memory agreementsToMigrateFunds = abi.decode(performData, (uint256[]));

    for (uint256 idx = 0; idx < agreementsToMigrateFunds.length; idx++) {
      migrateFunds(agreementsToMigrateFunds[idx]);
      depositFundsForNextCycle(agreementsToMigrateFunds[idx]);
    }
  }
  
  /**
   * @notice Closes an agreement and releases the escrowed funds accordingly to the agreement state
   * @param agreementID The ID of the agreement
   * @dev only callable by the contractee
   */
  function cancelAgreement(uint256 agreementID) external whenNotPaused {
    Types.Agreement storage agreement = agreements[agreementID];
    if (agreement.parameters.CONTRACTEE != msg.sender) {
      revert Errors.MG_UNAUTHORIZED();
    }

    agreement.state.closed = true;
    if (!agreement.state.active) {
      IERC20(agreement.parameters.UNDERLAYING_TOKEN).transfer(
        agreement.parameters.CONTRACTEE,
        agreement.state.escrowedFunds
      );
    } else {
      uint128 agreementDuration = agreement.parameters.MATURITY_DATE - agreement.parameters.BEGINNING_DATE;
      uint128 migrations = agreementDuration / agreement.parameters.PAYMENT_CYCLE_DURATION;
      bool reminder = agreementDuration % agreement.parameters.PAYMENT_CYCLE_DURATION != 0;
      uint128 paymentForSecond = agreement.parameters.PAYMENT_CYCLE_AMOUNT /
        agreement.parameters.PAYMENT_CYCLE_DURATION;
      for (uint128 i = 0; i < migrations; i++) {
        uint128 migrationStartPeriod = agreement.parameters.BEGINNING_DATE +
          (agreement.parameters.PAYMENT_CYCLE_DURATION * (i + 1));
        if (
          block.timestamp >= migrationStartPeriod &&
          block.timestamp <= migrationStartPeriod + agreement.parameters.PAYMENT_CYCLE_DURATION
        ) {
          IERC20(agreement.parameters.UNDERLAYING_TOKEN).transfer(
            agreement.parameters.CONTRACTOR,
            paymentForSecond * (block.timestamp - migrationStartPeriod) + agreement.parameters.PENALIZATION_AMOUNT
          );
          return;
        }
      }
      if (reminder) {
        if (
          block.timestamp >=
          agreement.parameters.BEGINNING_DATE + (agreement.parameters.PAYMENT_CYCLE_DURATION * (migrations)) &&
          block.timestamp <= agreement.parameters.MATURITY_DATE
        ) {
          IERC20(agreement.parameters.UNDERLAYING_TOKEN).transfer(
            agreement.parameters.CONTRACTOR,
            paymentForSecond *
              (agreement.parameters.MATURITY_DATE - block.timestamp) +
              agreement.parameters.PENALIZATION_AMOUNT
          );
          return;
        }
      }
    }

    emit AgreementCancelled(agreementID);
  }

  /**
   * @notice Sets the agreement state to challenged and emmits an event that will be captured by the Contractful DAO(
   * currently a multisig)
   * @param agreementID The ID of the agreement
   */
  function challengeAgreement(uint256 agreementID) external whenNotPaused whenOngoing(agreements[agreementID]) {
    Types.Agreement storage agreement = agreements[agreementID];

    agreement.state.challenged = true;

    emit AgreementChallenged(agreementID);
  }

  /**
   * @notice Releases the escrowed funds accordingly to the percentages passed as parameters
   * @notice For the moment the function is only callable by governance wich is a multisig wallet. However in the future
   * it will only be callable by the Contractful DAO
   * @param agreementID The ID of the agreement
   * @param contractorPercentage The percentage of the escrowed funds to be released to the contractor
   * @param contracteePercentage The percentage of the escrowed funds to be released to the contractee
   * @dev Only integers can be passed as pecentages. The function does't calculate for decimal points
   */
  function splitFunds(
    uint256 agreementID,
    uint128 contractorPercentage,
    uint128 contracteePercentage
  ) external whenNotPaused onlyRole(Roles.GOVERNANCE_ROLE) {
    Types.Agreement storage agreement = agreements[agreementID];

    assert(agreement.state.escrowedFunds != 0);

    agreement.state.closed = true;

    if (contractorPercentage + contracteePercentage != 100) {
      revert Errors.MG_INVALID_PERCENTAGES();
    }

    uint128 contractorAmount = (agreement.state.escrowedFunds * contractorPercentage) / 100;
    uint128 contracteeAmount = (agreement.state.escrowedFunds * contracteePercentage) / 100;

    IERC20(agreement.parameters.UNDERLAYING_TOKEN).transfer(agreement.parameters.CONTRACTOR, contractorAmount);
    IERC20(agreement.parameters.UNDERLAYING_TOKEN).transfer(agreement.parameters.CONTRACTEE, contracteeAmount);

    emit FundsSplitted(agreementID, contractorAmount, contracteeAmount);
  }

  // View Methods

  /**
   * @notice Returns the parameters of an agreement
   * @param agreementID The ID of the agreement
   * @return beginningDate The beginning date of the agreement
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
      uint128 beginningDate,
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
      agreement.parameters.BEGINNING_DATE,
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
   * @param closed Whether the agreement is closed
   * @param challenged Whether the agreement is challenged
   * @param active Whether the agreement is active
   */
  function getAgreementState(uint256 agreementID)
    external
    view
    returns (
      uint128 escrowedFunds,
      bool closed,
      bool challenged,
      bool active
    )
  {
    Types.Agreement storage agreement = agreements[agreementID];
    return (agreement.state.escrowedFunds, agreement.state.closed, agreement.state.challenged, agreement.state.active);
  }

  /**
   * @notice Returns the user agreements
   * @param user The address of the user
   * @return agreementIDs The IDs of the agreements
   */
  function getUserAgreements(address user) external view returns (uint256[] memory) {
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
