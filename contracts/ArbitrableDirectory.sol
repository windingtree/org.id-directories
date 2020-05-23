pragma solidity >=0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@windingtree/org.id/contracts/OrgIdInterface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IArbitrable, IArbitrator } from "@kleros/erc-792/contracts/IArbitrator.sol";
import "@kleros/erc-792/contracts/erc-1497/IEvidence.sol";
import "@kleros/ethereum-libraries/contracts/CappedMath.sol";

/* solium-disable max-len */
/* solium-disable security/no-block-members */
/* solium-disable security/no-send */ // It is the user responsibility to accept ETH.

/**
 *  @title ArbitrableDirectory
 *  @dev A Directory contract arbitrated by Kleros.
 *  Organizations are added or removed based on a ruling given by the arbitrator contract.
 *  NOTE: This contract trusts that the Arbitrator is honest and will not reenter or modify its costs during a call.
 *  The arbitrator must support appeal period.
 */
contract ArbitrableDirectory is Initializable, IArbitrable, IEvidence {

    using CappedMath for uint;

    /* Enums */

    enum Party {
        None, // Party per default when there is no challenger or requester. Also used for unconclusive ruling.
        Requester, // Party that makes a request to add the organization.
        Challenger // Party that challenges the request.
    }

    enum Status {
        Absent, // The organization is not registered and doesn't have an open request.
        RegistrationRequested, // The organization has an open request.
        WithdrawRequested, // The organization made a withdrawal request.
        Challenged, // The organization has been challenged.
        Disputed, // The challenge has been disputed.
        Registered // The organization is registered.
    }

    /* Structs */

    struct Organization {
        bytes32 ID; // The ID of the organization.
        Status status; // The current status of the organization.
        address requester; // The address that made the last registration request. It is possible to have multiple requests if the organization is added, then removed and then added again etc.
        uint requestTime; // The time when the last registration request was made. Is used to track the withdrawal period.
        uint lastStatusChange; // The time when the organization's status was updated. Only applies to the statuses that are time-sensitive, to track Execution and Response timeouts.
        uint lifStake; // The amount of Lif tokens, deposited by the requester when the request was made.
        Challenge[] challenges; // List of challenges made for the organization.
        uint withdrawRequestTime; // The time when the withdrawal request was made.
    }

    struct Challenge {
        bool disputed; // Whether the challenge has been disputed or not.
        uint disputeID; // The ID of the dispute raised in arbitrator contract, if any.
        bool resolved; // True if the request was executed or any raised disputes were resolved.
        address payable challenger; // The address that challenged the organization.
        Round[] rounds; // Tracks each round of a dispute.
        Party ruling; // The final ruling given by the arbitrator, if any.
        IArbitrator arbitrator; // The arbitrator trusted to solve a dispute for this challenge.
        bytes arbitratorExtraData; // The extra data for the trusted arbitrator of this challenge.
        uint metaEvidenceID; // The meta evidence to be used in a dispute for this case.
    }

    // Arrays with 3 elements map with the Party enum for better readability:
    // - 0: is unused, matches `Party.None`.
    // - 1: for `Party.Requester`.
    // - 2: for `Party.Challenger`.
    struct Round {
        uint[3] paidFees; // Tracks the fees paid for each Party in this round.
        bool[3] hasPaid; // True if the Party has fully paid its fee in this round.
        uint feeRewards; // Sum of reimbursable fees and stake rewards available to the parties that made contributions to the side that ultimately wins a dispute.
        mapping(address => uint[3]) contributions; // Maps contributors to their contributions for each side.
    }

    /* Storage */

    OrgIdInterface public orgId; // An instance of the ORG.ID smart contract.
    ERC20 public lif; // Lif token instance.

    string public segment; // Segment name, i.e. hotel, airline.
    address public governor; // The address that can make changes to the parameters of the contract.

    IArbitrator public arbitrator; // The arbitrator contract.
    bytes public arbitratorExtraData; // Extra data for the arbitrator contract.

    uint RULING_OPTIONS = 2; // The amount of non 0 choices the arbitrator can give.

    uint public requesterDeposit; // The amount of Lif tokens in base units a requester must deposit in order to open a request to add the organization.
    uint public challengeBaseDeposit; // The base deposit to challenge the organization. Also the base deposit to accept the challenge.

    uint public executionTimeout; // The time after which the organization can be added to the directory if not challenged.
    uint public responseTimeout; // The time the requester has to accept the challenge, or he will lose otherwise. Note that any other address can accept the challenge on requester's behalf.
    uint public withdrawRequestTimeout; // The time organization's owner has to make a request to withdraw the organization from the directory.
    uint public withdrawTimeout; // The time after which it becomes possible to execute the withdrawal request and withdraw the Lif stake. The organization can still be challenged during this time, but not after.

    uint public metaEvidenceUpdates; // The number of times the meta evidence has been updated. Is used to track the latest meta evidence ID.

    // Multipliers are in basis points.
    uint public winnerStakeMultiplier; // Multiplier for calculating the fee stake paid by the party that won the previous round.
    uint public loserStakeMultiplier; // Multiplier for calculating the fee stake paid by the party that lost the previous round.
    uint public sharedStakeMultiplier; // Multiplier for calculating the fee stake that must be paid in the case where arbitrator refused to arbitrate.
    uint public constant MULTIPLIER_DIVISOR = 10000; // Divisor parameter for multipliers.

    bytes32[] public registeredOrganizations; // Stores all added organizations.
    mapping(bytes32 => Organization) public organizationData; // Maps the organization to its data. organizationData[_organization].
    mapping(bytes32 => uint) public organizationsIndex; // Maps the organization to its index in the array. organizationsIndex[_organization].
    mapping(address => mapping(uint => bytes32)) public arbitratorDisputeIDToOrg; // Maps a dispute ID to the organization ID. arbitratorDisputeIDToOrg[_arbitrator][_disputeID].

    /* Modifiers */

    modifier onlyGovernor {require(msg.sender == governor, "The caller must be the governor."); _;}

    /* Events */

    /** @dev Event triggered every time segment value is changed.
     *  @param _previousSegment Previous name of the segment.
     *  @param _newSegment New name of the segment.
     */
    event SegmentChanged(string _previousSegment, string _newSegment);

    /** @dev Event triggered every time organization is added.
     *  @param _organization The organization that was added.
     *  @param _index Organization's index in the array.
     */
    event OrganizationAdded(bytes32 indexed _organization, uint _index);

    /** @dev Event triggered every time organization is removed.
     *  @param _organization The organization that was removed.
     */
    event OrganizationRemoved(bytes32 indexed _organization);

    /* External and Public */

    // ************************ //
    // *      Governance      * //
    // ************************ //

    /**
     *  @dev Initializer for upgradeable contracts.
     *  @param _governor The trusted governor of this contract.
     *  @param _segment The segment name.
     *  @param _orgId The address of the ORG.ID contract.
     *  @param _lif The address of the Lif token.
     *  @param _arbitrator Arbitrator to resolve potential disputes. The arbitrator is trusted to support appeal periods and not reenter.
     *  @param _arbitratorExtraData Extra data for the trusted arbitrator contract.
     *  @param _metaEvidence The URI of the meta evidence object.
     *  @param _requesterDeposit The amount of Lif tokens in base units required to make a request.
     *  @param _challengeBaseDeposit The base deposit to challenge a request or to accept the challenge.
     *  @param _executionTimeout The time after which the organization will be registered if not challenged.
     *  @param _responseTimeout The time the requester has to answer to challenge.
     *  @param _withdrawRequestTimeout The time the organization's owner has to make a withdrawal request.
     *  @param _withdrawTimeout The time after which it becomes possible to execute the withdrawal request.
     *  @param _stakeMultipliers Multipliers of the arbitration cost in basis points (see MULTIPLIER_DIVISOR) as follows:
     *  - The multiplier applied to each party's fee stake for a round when there is no winner/loser in the previous round.
     *  - The multiplier applied to the winner's fee stake for the subsequent round.
     *  - The multiplier applied to the loser's fee stake for the subsequent round.
     */
    function initialize(
        address _governor,
        string memory _segment,
        OrgIdInterface _orgId,
        ERC20 _lif,
        IArbitrator _arbitrator,
        bytes memory _arbitratorExtraData,
        string memory _metaEvidence,
        uint _requesterDeposit,
        uint _challengeBaseDeposit,
        uint _executionTimeout,
        uint _responseTimeout,
        uint _withdrawRequestTimeout,
        uint _withdrawTimeout,
        uint[3] memory _stakeMultipliers
    ) public initializer {
        emit MetaEvidence(metaEvidenceUpdates, _metaEvidence);
        governor = _governor;
        segment = _segment;
        orgId = _orgId;
        lif = _lif;

        arbitrator = _arbitrator;
        arbitratorExtraData = _arbitratorExtraData;
        requesterDeposit = _requesterDeposit;
        challengeBaseDeposit = _challengeBaseDeposit;
        executionTimeout = _executionTimeout;
        responseTimeout = _responseTimeout;
        withdrawRequestTimeout = _withdrawRequestTimeout;
        withdrawTimeout = _withdrawTimeout;
        sharedStakeMultiplier = _stakeMultipliers[0];
        winnerStakeMultiplier = _stakeMultipliers[1];
        loserStakeMultiplier = _stakeMultipliers[2];

        organizationsIndex[bytes32(0)] = registeredOrganizations.length;
        registeredOrganizations.push(bytes32(0));
    }

    /**
     *  @dev Allows the owner of the contract to change the segment name.
     *  @param _segment The new segment name.
     */
    function setSegment(string calldata _segment) external onlyGovernor {
        emit SegmentChanged(segment, _segment);
        segment = _segment;
    }

    /** @dev Change the Lif token amount required to make a request.
     *  @param _requesterDeposit The new Lif token amount required to make a request.
     */
    function changeRequesterDeposit(uint _requesterDeposit) external onlyGovernor {
        requesterDeposit = _requesterDeposit;
    }

    /** @dev Change the base amount required as a deposit to challenge the organization or to accept the challenge.
     *  @param _challengeBaseDeposit The new base amount of wei required to challenge or to accept the challenge.
     */
    function changeChallengeBaseDeposit(uint _challengeBaseDeposit) external onlyGovernor {
        challengeBaseDeposit = _challengeBaseDeposit;
    }

    /** @dev Change the duration of the timeout after which the organization can be registered if not challenged.
     *  @param _executionTimeout The new duration of the execution timeout.
     */
    function changeExecutionTimeout(uint _executionTimeout) external onlyGovernor {
        executionTimeout = _executionTimeout;
    }

    /** @dev Change the duration of the time the requester has to accept the challenge.
     *  @param _responseTimeout The new duration of the response timeout.
     */
    function changeResponseTimeout(uint _responseTimeout) external onlyGovernor {
        responseTimeout = _responseTimeout;
    }

    /** @dev Change the time organization's owner has to make a withdrawal request.
     *  @param _withdrawRequestTimeout The new duration of the withdrawRequest timeout.
     */
    function changeWithdrawRequestTimeout(uint _withdrawRequestTimeout) external onlyGovernor {
        withdrawRequestTimeout = _withdrawRequestTimeout;
    }

    /** @dev Change the duration of the time after which it becomes possible to execute the withdrawal request.
     *  @param _withdrawTimeout The new duration of the withdraw timeout.
     */
    function changeWithdrawTimeout(uint _withdrawTimeout) external onlyGovernor {
        withdrawTimeout = _withdrawTimeout;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by parties when there is no winner or loser.
     *  @param _sharedStakeMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeSharedStakeMultiplier(uint _sharedStakeMultiplier) external onlyGovernor {
        sharedStakeMultiplier = _sharedStakeMultiplier;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by the winner of the previous round.
     *  @param _winnerStakeMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeWinnerStakeMultiplier(uint _winnerStakeMultiplier) external onlyGovernor {
        winnerStakeMultiplier = _winnerStakeMultiplier;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by the party that lost the previous round.
     *  @param _loserStakeMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeLoserStakeMultiplier(uint _loserStakeMultiplier) external onlyGovernor {
        loserStakeMultiplier = _loserStakeMultiplier;
    }

    /** @dev Change the arbitrator to be used for disputes that may be raised. The arbitrator is trusted to support appeal periods and not reenter.
     *  @param _arbitrator The new trusted arbitrator to be used in disputes.
     *  @param _arbitratorExtraData The extra data used by the new arbitrator.
     */
    function changeArbitrator(IArbitrator _arbitrator, bytes calldata _arbitratorExtraData) external onlyGovernor {
        arbitrator = _arbitrator;
        arbitratorExtraData = _arbitratorExtraData;
    }

    /** @dev Update the meta evidence used for disputes.
     *  @param _metaEvidence The meta evidence to be used for future disputes.
     */
    function changeMetaEvidence(string calldata _metaEvidence) external onlyGovernor {
        metaEvidenceUpdates++;
        emit MetaEvidence(metaEvidenceUpdates, _metaEvidence);
    }

    // ****************************** //
    // *   Requests and Challenges  * //
    // ****************************** //

    /** @dev Make a request to add the organization to the directory. Requires a Lif deposit.
     *  @param _organization The ID of the organization.
     */
    function requestToAdd(bytes32 _organization) external {
        Organization storage organization = organizationData[_organization];
        // Get the organization info from the ORG.ID registry.
        (bool exist,,,,, address orgOwner, address director, bool orgState, bool directorConfirmed,) = orgId.getOrganization(_organization);

        require(organization.status == Status.Absent, "Directory: The organization has wrong status.");
        require(exist, "Directory: Organization not found.");
        require(orgOwner == msg.sender || director == msg.sender, "Directory: Only organization owner or director can add the organization.");
        require(orgState, "Directory: Only enabled organizations can be added.");

        if (director != address(0))
            require(directorConfirmed, "Directory: Only subsidiaries with confirmed director ownership can be added.");

        organization.ID = _organization;
        organization.status = Status.RegistrationRequested;
        organization.requester = msg.sender;
        organization.requestTime = now;
        organization.lastStatusChange = now;
        organization.lifStake = requesterDeposit;
        require(lif.transferFrom(msg.sender, address(this), requesterDeposit), "Directory: The token transfer must not fail.");
    }

    /** @dev Challenge the organization. Accept enough ETH to cover the deposit, reimburse the rest.
     *  @param _organization The ID of the organization to challenge.
     *  @param _evidence A link to evidence using its URI. Ignored if not provided.
     */
    function challengeOrganization(bytes32 _organization, string calldata _evidence) external payable {
        Organization storage organization = organizationData[_organization];
        require(
            organization.status == Status.RegistrationRequested || organization.status == Status.Registered || organization.status == Status.WithdrawRequested,
            "Directory: The organization should be either registered or registering."
        );
        if (organization.status == Status.WithdrawRequested)
            require(now - organization.withdrawRequestTime <= withdrawTimeout, "Time to challenge the withdrawn organization has passed.");
        Challenge storage challenge = organization.challenges[organization.challenges.length++];
        organization.status = Status.Challenged;
        organization.lastStatusChange = now;

        challenge.challenger = msg.sender;
        challenge.arbitrator = arbitrator;
        challenge.arbitratorExtraData = arbitratorExtraData;
        challenge.metaEvidenceID = metaEvidenceUpdates;

        Round storage round = challenge.rounds[challenge.rounds.length++];

        uint arbitrationCost = challenge.arbitrator.arbitrationCost(challenge.arbitratorExtraData);
        uint totalCost = arbitrationCost.addCap(challengeBaseDeposit);
        contribute(round, Party.Challenger, msg.sender, msg.value, totalCost);
        require(round.paidFees[uint(Party.Challenger)] >= totalCost, "Directory: You must fully fund your side.");
        round.hasPaid[uint(Party.Challenger)] = true;

        if (bytes(_evidence).length > 0)
            emit Evidence(challenge.arbitrator, uint(keccak256(abi.encodePacked(_organization, organization.challenges.length))), msg.sender, _evidence);
    }

    /** @dev Answer to the challenge and create a dispute. Accept enough ETH to cover the deposit, reimburse the rest.
     *  @param _organization The ID of the organization which challenge to accept.
     *  @param _evidence A link to evidence using its URI. Ignored if not provided.
     */
    function acceptChallenge(bytes32 _organization, string calldata _evidence) external payable {
        Organization storage organization = organizationData[_organization];
        require(organization.status == Status.Challenged, "Directory: The organization should have status Challenged.");
        require(now - organization.lastStatusChange <= responseTimeout, "Directory: Time to accept the challenge has passed.");

        Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
        organization.status = Status.Disputed;
        Round storage round = challenge.rounds[0];
        uint arbitrationCost = challenge.arbitrator.arbitrationCost(challenge.arbitratorExtraData);
        uint totalCost = arbitrationCost.addCap(challengeBaseDeposit);
        contribute(round, Party.Requester, msg.sender, msg.value, totalCost);
        require(round.paidFees[uint(Party.Requester)] >= totalCost, "Directory: You must fully fund your side.");
        round.hasPaid[uint(Party.Requester)] = true;

        // Raise a dispute.
        challenge.disputeID = challenge.arbitrator.createDispute.value(arbitrationCost)(RULING_OPTIONS, challenge.arbitratorExtraData);
        arbitratorDisputeIDToOrg[address(challenge.arbitrator)][challenge.disputeID] = _organization;
        challenge.disputed = true;
        challenge.rounds.length++;
        round.feeRewards = round.feeRewards.subCap(arbitrationCost);

        uint evidenceGroupID = uint(keccak256(abi.encodePacked(_organization, organization.challenges.length)));
        emit Dispute(challenge.arbitrator, challenge.disputeID, challenge.metaEvidenceID, evidenceGroupID);

        if (bytes(_evidence).length > 0)
            emit Evidence(challenge.arbitrator, evidenceGroupID, msg.sender, _evidence);
    }

    /** @dev Execute an unchallenged request if the execution timeout has passed, or execute the challenge if it wasn't accepted during response timeout.
     *  @param _organization The ID of the organization.
     */
    function executeTimeout(bytes32 _organization) external {
        Organization storage organization = organizationData[_organization];
        require(
            organization.status == Status.RegistrationRequested || organization.status == Status.Challenged,
            "Directory: The organization must have a pending status and not be disputed."
        );

        if (organization.status == Status.RegistrationRequested) {
            require(now - organization.lastStatusChange > executionTimeout, "Directory: Time to challenge the request must pass.");
            organization.status = Status.Registered;
            if (organizationsIndex[_organization] == 0) {
                organizationsIndex[_organization] = registeredOrganizations.length;
                registeredOrganizations.push(_organization);
                emit OrganizationAdded(_organization, organizationsIndex[_organization]);
            }
        } else {
            require(now - organization.lastStatusChange > responseTimeout, "Directory: Time to respond to the challenge must pass.");
            organization.status = Status.Absent;
            if (organization.withdrawRequestTime != 0)
                organization.withdrawRequestTime = 0;
            Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
            challenge.resolved = true;
            uint stake = organization.lifStake;
            organization.lifStake = 0;
            require(lif.transfer(challenge.challenger, stake), "Directory: The token transfer must not fail.");
            if (organizationsIndex[_organization] != 0) {
                uint index = organizationsIndex[_organization];
                bytes32 lastOrg = registeredOrganizations[registeredOrganizations.length - 1];
                registeredOrganizations[index] = lastOrg;
                organizationsIndex[lastOrg] = index;
                registeredOrganizations.length--;
                organizationsIndex[_organization] = 0;
                emit OrganizationRemoved(_organization);
            }
        }
    }

    /** @dev Take up to the total amount required to fund a side of an appeal. Reimburse the rest. Create an appeal if both sides are fully funded.
     *  @param _organization The ID of the organization.
     *  @param _side The recipient of the contribution.
     */
    function fundAppeal(bytes32 _organization, Party _side) external payable {
        require(_side == Party.Requester || _side == Party.Challenger, "Directory: Invalid party.");
        require(organizationData[_organization].status == Status.Disputed, "Directory: The organization must have an open dispute.");
        Challenge storage challenge = organizationData[_organization].challenges[organizationData[_organization].challenges.length - 1];
        (uint appealPeriodStart, uint appealPeriodEnd) = challenge.arbitrator.appealPeriod(challenge.disputeID);
        require(
            now >= appealPeriodStart && now < appealPeriodEnd,
            "Directory: Contributions must be made within the appeal period."
        );

        uint multiplier;
        Party winner = Party(challenge.arbitrator.currentRuling(challenge.disputeID));
        Party loser;
        if (winner == Party.Requester)
            loser = Party.Challenger;
        else if (winner == Party.Challenger)
            loser = Party.Requester;
        require(
            _side != loser || (now-appealPeriodStart < (appealPeriodEnd-appealPeriodStart)/2),
            "Directory: The loser must contribute during the first half of the period.");

        if (_side == winner)
            multiplier = winnerStakeMultiplier;
        else if (_side == loser)
            multiplier = loserStakeMultiplier;
        else
            multiplier = sharedStakeMultiplier;

        Round storage round = challenge.rounds[challenge.rounds.length - 1];
        uint appealCost = challenge.arbitrator.appealCost(challenge.disputeID, challenge.arbitratorExtraData);
        uint totalCost = appealCost.addCap((appealCost.mulCap(multiplier)) / MULTIPLIER_DIVISOR);
        contribute(round, _side, msg.sender, msg.value, totalCost);

        if (round.paidFees[uint(_side)] >= totalCost)
            round.hasPaid[uint(_side)] = true;

        // Raise appeal if both sides are fully funded.
        if (round.hasPaid[uint(Party.Challenger)] && round.hasPaid[uint(Party.Requester)]) {
            challenge.arbitrator.appeal.value(appealCost)(challenge.disputeID, challenge.arbitratorExtraData);
            challenge.rounds.length++;
            round.feeRewards = round.feeRewards.subCap(appealCost);
        }
    }

    /** @dev Reimburse contributions if no disputes were raised. If a dispute was raised, send the fee stake rewards and reimbursements proportionally to the contributions made to the winner of a dispute.
     *  @param _beneficiary The address that made contributions.
     *  @param _organization The ID of the organization.
     *  @param _challenge The challenge from which to withdraw.
     *  @param _round The round from which to withdraw.
     */
    function withdrawFeesAndRewards(address payable _beneficiary, bytes32 _organization, uint _challenge, uint _round) external {
        Organization storage organization = organizationData[_organization];
        Challenge storage challenge = organization.challenges[_challenge];
        Round storage round = challenge.rounds[_round];
        require(challenge.resolved, "Directory: The challenge must be resolved.");

        uint reward;
        if (!round.hasPaid[uint(Party.Requester)] || !round.hasPaid[uint(Party.Challenger)]) {
            // Reimburse if not enough fees were raised to appeal the ruling.
            reward = round.contributions[_beneficiary][uint(Party.Requester)] + round.contributions[_beneficiary][uint(Party.Challenger)];
        } else if (challenge.ruling == Party.None) {
            // Reimburse unspent fees proportionally if there is no winner or loser.
            uint rewardRequester = round.paidFees[uint(Party.Requester)] > 0
                ? (round.contributions[_beneficiary][uint(Party.Requester)] * round.feeRewards) / (round.paidFees[uint(Party.Challenger)] + round.paidFees[uint(Party.Requester)])
                : 0;
            uint rewardChallenger = round.paidFees[uint(Party.Challenger)] > 0
                ? (round.contributions[_beneficiary][uint(Party.Challenger)] * round.feeRewards) / (round.paidFees[uint(Party.Challenger)] + round.paidFees[uint(Party.Requester)])
                : 0;

            reward = rewardRequester + rewardChallenger;
        } else {
            // Reward the winner.
            reward = round.paidFees[uint(challenge.ruling)] > 0
                ? (round.contributions[_beneficiary][uint(challenge.ruling)] * round.feeRewards) / round.paidFees[uint(challenge.ruling)]
                : 0;

        }
        round.contributions[_beneficiary][uint(Party.Requester)] = 0;
        round.contributions[_beneficiary][uint(Party.Challenger)] = 0;

        _beneficiary.send(reward);
    }

    /** @dev Make a request to remove the organization and withdraw Lif tokens from the directory. The organization is removed right away but the tokens can only be withdrawn after withdrawTimeout, to prevent frontrunning the challengers.
     *  @param _organization The ID of the organization.
     */
    function makeWihdrawalRequest(bytes32 _organization) external {
        Organization storage organization = organizationData[_organization];
        require(
            organization.status == Status.RegistrationRequested || organization.status == Status.Registered,
            "Directory: The organization has wrong status."
        );
        require(now - organization.requestTime <= withdrawRequestTimeout, "Directory: Time to make a withdrawal request has passed.");
        (,,,,, address orgOwner, address director,,bool directorConfirmed,) = orgId.getOrganization(_organization);
        require(orgOwner == msg.sender || director == msg.sender, "Directory: Only organization owner or director can request a withdraw.");
        if (director != address(0))
            require(directorConfirmed, "Directory: The director should be confirmed.");

        organization.withdrawRequestTime = now;
        organization.status = Status.WithdrawRequested;
        uint index = organizationsIndex[_organization];
        if (index != 0) {
            bytes32 lastOrg = registeredOrganizations[registeredOrganizations.length - 1];
            registeredOrganizations[index] = lastOrg;
            organizationsIndex[lastOrg] = index;
            registeredOrganizations.length--;
            organizationsIndex[_organization] = 0;
        }
    }

    /** @dev Withdraw all the Lif tokens deposited when the request was made.
     *  @param _organization The ID of the organization to un-register.
     */
    function withdrawTokens(bytes32 _organization) external {
        Organization storage organization = organizationData[_organization];
        require(
            organization.status == Status.WithdrawRequested,
            "Directory: The organization has wrong status."
        );
        require(now - organization.withdrawRequestTime > withdrawTimeout, "Directory: Tokens can only be withdrawn after the timeout.");
        (,,,,, address orgOwner,,,,) = orgId.getOrganization(_organization);
        organization.status = Status.Absent;
        organization.withdrawRequestTime = 0;
        uint stake = organization.lifStake;
        organization.lifStake = 0;
        require(lif.transfer(orgOwner, stake), "Directory: The token transfer must not fail.");
    }

    /** @dev Give a ruling for a dispute. Can only be called by the arbitrator. TRUSTED.
     *  Accounts for the situation where the winner loses a case due to paying less appeal fees than expected.
     *  @param _disputeID ID of the dispute in the arbitrator contract.
     *  @param _ruling Ruling given by the arbitrator. Note that 0 is reserved for "Refused to arbitrate".
     */
    function rule(uint _disputeID, uint _ruling) public {
        Party resultRuling = Party(_ruling);
        bytes32 organizationID = arbitratorDisputeIDToOrg[msg.sender][_disputeID];
        Organization storage organization = organizationData[organizationID];

        Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
        Round storage round = challenge.rounds[challenge.rounds.length - 1];
        require(_ruling <= RULING_OPTIONS, "Directory: Invalid ruling option.");
        require(address(challenge.arbitrator) == msg.sender, "Directory: Only the arbitrator can give a ruling.");
        require(!challenge.resolved, "Directory: The challenge must not be resolved.");

        // If one side paid its fees, the ruling is in its favor. Note that if the other side had also paid, an appeal would have been created.
        if (round.hasPaid[uint(Party.Requester)] == true)
            resultRuling = Party.Requester;
        else if (round.hasPaid[uint(Party.Challenger)] == true)
            resultRuling = Party.Challenger;

        emit Ruling(IArbitrator(msg.sender), _disputeID, uint(resultRuling));
        executeRuling(_disputeID, uint(resultRuling));
    }

    /** @dev Submit a reference to evidence. EVENT.
     *  @param _organization The ID of the organization which the evidence is related to.
     *  @param _evidence A link to evidence using its URI.
     */
    function submitEvidence(bytes32 _organization, string calldata _evidence) external {
        Organization storage organization = organizationData[_organization];

        uint evidenceGroupID = uint(keccak256(abi.encodePacked(_organization, organization.challenges.length)));
        if (bytes(_evidence).length > 0) {
            if (organization.challenges.length > 0) {
                Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
                require(!challenge.resolved, "The challenge must not be resolved.");
                emit Evidence(challenge.arbitrator, evidenceGroupID, msg.sender, _evidence);
            } else
                emit Evidence(arbitrator, evidenceGroupID, msg.sender, _evidence);
        }
    }

    /* Internal */

    /** @dev Return the contribution value and remainder from available ETH and required amount.
     *  @param _available The amount of ETH available for the contribution.
     *  @param _requiredAmount The amount of ETH required for the contribution.
     *  @return taken The amount of ETH taken.
     *  @return remainder The amount of ETH left from the contribution.
     */
    function calculateContribution(uint _available, uint _requiredAmount)
        internal
        pure
        returns(uint taken, uint remainder)
    {
        if (_requiredAmount > _available)
            return (_available, 0); // Take whatever is available, return 0 as leftover ETH.
        else
            return (_requiredAmount, _available - _requiredAmount);
    }

    /** @dev Make a fee contribution.
     *  @param _round The round to contribute.
     *  @param _side The side for which to contribute.
     *  @param _contributor The contributor.
     *  @param _amount The amount contributed.
     *  @param _totalRequired The total amount required for this side.
     *  @return The amount of appeal fees contributed.
     */
    function contribute(Round storage _round, Party _side, address payable _contributor, uint _amount, uint _totalRequired) internal returns (uint) {
        // Take up to the amount necessary to fund the current round at the current costs.
        uint contribution; // Amount contributed.
        uint remainingETH; // Remaining ETH to send back.
        (contribution, remainingETH) = calculateContribution(_amount, _totalRequired.subCap(_round.paidFees[uint(_side)]));
        _round.contributions[_contributor][uint(_side)] += contribution;
        _round.paidFees[uint(_side)] += contribution;
        _round.feeRewards += contribution;

        // Reimburse leftover ETH.
        _contributor.send(remainingETH); // Deliberate use of send in order to not block the contract in case of reverting fallback.

        return contribution;
    }

    /** @dev Execute the ruling of a dispute.
     *  @param _disputeID ID of the dispute in the arbitrator contract.
     *  @param _ruling Ruling given by the arbitrator. Note that 0 is reserved for "Refused to arbitrate".
     */
    function executeRuling(uint _disputeID, uint _ruling) internal {
        bytes32 organizationID = arbitratorDisputeIDToOrg[msg.sender][_disputeID];
        Organization storage organization = organizationData[organizationID];
        Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
        Party winner = Party(_ruling);
        uint stake = organization.lifStake;
        (,,,,, address orgOwner,,,,) = orgId.getOrganization(organization.ID);
        if (winner == Party.Requester) {
            // If the organization is challenged during withdrawal process just send tokens to the orgOwner and set the status to default. The organization is not added in this case.
            if (organization.withdrawRequestTime != 0) {
                organization.withdrawRequestTime = 0;
                organization.status = Status.Absent;
                organization.lifStake = 0;
                require(lif.transfer(orgOwner, stake), "Directory: The token transfer must not fail.");
            } else {
                organization.status = Status.Registered;
                // Add the organization if it's not in the directory.
                if (organizationsIndex[organization.ID] == 0) {
                    organizationsIndex[organization.ID] = registeredOrganizations.length;
                    registeredOrganizations.push(organization.ID);
                    emit OrganizationAdded(organization.ID, organizationsIndex[organization.ID]);
                }
            }
        // Remove the organization if it is in the directory. Send Lif tokens to the challenger.
        } else if (winner == Party.Challenger) {
            organization.status = Status.Absent;
            if (organization.withdrawRequestTime != 0)
                organization.withdrawRequestTime = 0;
            organization.lifStake = 0;
            require(lif.transfer(challenge.challenger, stake), "Directory: The token transfer must not fail.");
            if (organizationsIndex[organization.ID] != 0) {
                uint index = organizationsIndex[organization.ID];
                bytes32 lastOrg = registeredOrganizations[registeredOrganizations.length - 1];
                registeredOrganizations[index] = lastOrg;
                organizationsIndex[lastOrg] = index;
                registeredOrganizations.length--;
                organizationsIndex[organization.ID] = 0;
                emit OrganizationRemoved(organization.ID);
            }
        // 0 ruling. Revert the organization to its default state.
        } else {
            if (organizationsIndex[organization.ID] == 0) {
                organization.status = Status.Absent;
                if (organization.withdrawRequestTime != 0)
                    organization.withdrawRequestTime = 0;
                organization.lifStake = 0;
                require(lif.transfer(orgOwner, stake), "Directory: The token transfer must not fail.");
            // Stake of the already registered organization stays in the contract in this case.
            } else
                organization.status = Status.Registered;
        }

        challenge.resolved = true;
        challenge.ruling = Party(_ruling);
    }

    // ************************ //
    // *       Getters        * //
    // ************************ //

    /** @dev Get all the registered organizations.
     *  @return organizationsList Array of organization IDs.
     */
    function getOrganizations()
        external
        view
        returns (bytes32[] memory organizationsList)
    {
        organizationsList = new bytes32[](_getOrganizationsCount());
        uint index;
        for (uint i = 0; i < registeredOrganizations.length; i++) {
            if (registeredOrganizations[i] != bytes32(0)) {
                organizationsList[index] = registeredOrganizations[i];
                index++;
            }
        }
    }

    /** @dev Return registeredOrganizations array length.
     *  @return count Length of the organizations array.
     */
    function _getOrganizationsCount() internal view returns (uint count) {
        for (uint i = 0; i < registeredOrganizations.length; i++) {
            if (registeredOrganizations[i] != bytes32(0))
               count++;
        }
    }

    /** @dev Get the contributions made by a party for a given round of a challenge.
     *  @param _organization The ID of the organization.
     *  @param _challenge The challenge to query.
     *  @param _round The round to query.
     *  @param _contributor The address of the contributor.
     *  @return The contributions.
     */
    function getContributions(
        bytes32 _organization,
        uint _challenge,
        uint _round,
        address _contributor
    ) external view returns (uint[3] memory contributions) {
        Organization storage organization = organizationData[_organization];
        Challenge storage challenge = organization.challenges[_challenge];
        Round storage round = challenge.rounds[_round];
        contributions = round.contributions[_contributor];
    }

    /** @dev Get the number of challenges of the organization.
     *  @param _organization The ID of the organization.
     *  @return numberOfChallenges Total number of times the organization was challenged.
     */
    function getNumberOfChallenges(bytes32 _organization)
        external
        view
        returns (
            uint numberOfChallenges
        )
    {
        Organization storage organization = organizationData[_organization];
        return (
            organization.challenges.length
        );
    }

    /** @dev Get the information of a challenge made for the organization.
     *  @param _organization The ID of the organization.
     *  @param _challenge The challenge to query.
     *  @return The challenge information.
     */
    function getChallengeInfo(bytes32 _organization, uint _challenge)
        external
        view
        returns (
            bool disputed,
            uint disputeID,
            bool resolved,
            address payable challenger,
            uint numberOfRounds,
            Party ruling,
            IArbitrator arbitrator,
            bytes memory arbitratorExtraData,
            uint metaEvidenceID
        )
    {
        Challenge storage challenge = organizationData[_organization].challenges[_challenge];
        return (
            challenge.disputed,
            challenge.disputeID,
            challenge.resolved,
            challenge.challenger,
            challenge.rounds.length,
            challenge.ruling,
            challenge.arbitrator,
            challenge.arbitratorExtraData,
            challenge.metaEvidenceID
        );
    }

    /** @dev Get the information of a round of a challenge.
     *  @param _organization The ID of the organization.
     *  @param _challenge The request to query.
     *  @param _round The round to be query.
     *  @return The round information.
     */
    function getRoundInfo(bytes32 _organization, uint _challenge, uint _round)
        external
        view
        returns (
            bool appealed,
            uint[3] memory paidFees,
            bool[3] memory hasPaid,
            uint feeRewards
        )
    {
        Organization storage organization = organizationData[_organization];
        Challenge storage challenge = organization.challenges[_challenge];
        Round storage round = challenge.rounds[_round];
        return (
            _round != (challenge.rounds.length - 1),
            round.paidFees,
            round.hasPaid,
            round.feeRewards
        );
    }
}