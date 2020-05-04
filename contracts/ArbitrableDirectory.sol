pragma solidity >=0.5.16;

import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@windingtree/org.id/contracts/OrgIdInterface.sol";
import "./DirectoryInterface.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IArbitrable, IArbitrator } from "@kleros/erc-792/contracts/IArbitrator.sol";
import "@kleros/erc-792/contracts/erc-1497/IEvidence.sol";
import "@kleros/ethereum-libraries/contracts/CappedMath.sol";

/* solium-disable max-len */
/* solium-disable security/no-block-members */
/* solium-disable security/no-send */ // It is the user responsibility to accept ETH.

/**
 *  @title ArbitrableDirectory
 *  @dev A Directory contract arbitrated by Kleros.
 *  In order to add or remove an organization from the directory firstly it should be given a corresponding verdict by the arbitrator contract.
 *  NOTE: This contract trusts that the Arbitrator is honest and will not reenter or modify its costs during a call.
 *  The arbitrator must support appeal period.
 */
contract ArbitrableDirectory is DirectoryInterface, Ownable, ERC165, Initializable, IArbitrable, IEvidence {

    using CappedMath for uint;
    using SafeERC20 for IERC20;

    /* Enums */

    enum Verdict  {
        NONE, // No verdict has been given to the organization.
        ADD, // The organization can be added to the directory.
        REMOVE // The organization can be removed from the directory.
    }

    enum Party {
        None, // Party per default when there is no challenger or requester. Also used for unconclusive ruling.
        Requester, // Party that made a request to add the organization.
        Challenger // Party that challenges the request.
    }

    enum Status {
        Absent, // The organization is not registered and doesn't have an open request.
        RegistrationRequested, // The organization has an open request.
        Challenged, // The organization's request has been challenged.
        Disputed, // The organization's request has been disputed.
        Registered // The organization is considered registered.
    }

    /* Structs */

    struct Organization {
        bytes32 ID; // The ID of the organization.
        Status status; // The current status of the organization.
        Verdict verdict; // Whether the organization can be added or removed.
        address[] requesters; // List of addresses that made a request to add the organization to the directory. It is possible to have multiple requests if the organization is added, then removed and then added again etc.
        uint requestTime; // The time when the recent request was made. Is used to track the withdrawal period.
        uint lastStatusChange; // The time when the organization's status was updated. Only applies to the statuses that are time-sensitive, to track Execution and Response timeouts.
        IERC20 lif; // The address of the Lif token used by the contract.
        uint lifStake; // The amount of Lif tokens, deposited by the requester when the request was made.
        Challenge[] challenges; // List of challenges made for the organization.
    }

    struct Challenge {
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
    IERC20 public lif; // Lif token instance.

    string internal segment; // Segment name, i.e. hotel, airline.

    IArbitrator public arbitrator; // The arbitrator contract.
    bytes public arbitratorExtraData; // Extra data for the arbitrator contract.

    uint RULING_OPTIONS = 2; // The amount of non 0 choices the arbitrator can give.

    uint public requesterDeposit; // The amount of Lif tokens a requester must deposit in order to open a request to add the organization.
    uint public challengeBaseDeposit; // The base deposit to challenge the organization. Also the base deposit to accept the challenge.

    uint public executionTimeout; // The time after which the organization can be added to the directory if not challenged.
    uint public responseTimeout; // The time the requester has to accept the challenge, or he will lose otherwise.
    uint public withdrawTimeout; // The time the requester has to withdraw his Lif stake and un-register the organization from the directory.

    uint public metaEvidenceUpdates; // The number of times the meta evidence has been updated. Is used to track the latest meta evidence ID.

    // Multipliers are in basis points.
    uint public winnerStakeMultiplier; // Multiplier for calculating the fee stake paid by the party that won the previous round.
    uint public loserStakeMultiplier; // Multiplier for calculating the fee stake paid by the party that lost the previous round.
    uint public sharedStakeMultiplier; // Multiplier for calculating the fee stake that must be paid in the case where arbitrator refused to arbitrate.
    uint public constant MULTIPLIER_DIVISOR = 10000; // Divisor parameter for multipliers.

    bytes32[] public organizations; // Stores all added organizations.
    mapping(bytes32 => Organization) public organizationData; // Maps the organization to its data. organizationData[_organization].
    mapping(bytes32 => uint) public organizationsIndex; // Maps the organization to its index in the array. organizationsIndex[_organization].
    mapping(address => mapping(uint => bytes32)) public arbitratorDisputeIDToOrg; // Maps a dispute ID to the organization. arbitratorDisputeIDToOrg[_arbitrator][_disputeID].

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

    /** @dev Event emitted when address of the Lif token is changed.
     *  @param _previousAddress Previous address of the Lif token.
     *  @param _newAddress New address of the Lif token.
     */
    event LifTokenChanged(address indexed _previousAddress, address indexed _newAddress);

    /* External and Public */

    // ************************ //
    // *      Governance      * //
    // ************************ //

    /**
     *  @dev Initializer for upgradeable contracts.
     *  @param _owner The address of the contract owner.
     *  @param _segment The segment name.
     *  @param _orgId The address of the ORG.ID contract.
     *  @param _lif The address of the Lif token.
     *  @param _arbitrator Arbitrator to resolve potential disputes. The arbitrator is trusted to support appeal periods and not reenter.
     *  @param _arbitratorExtraData Extra data for the trusted arbitrator contract.
     *  @param _metaEvidence The URI of the meta evidence object.
     *  @param _requesterDeposit The amount of Lif tokens required to make a request.
     *  @param _challengeBaseDeposit The base deposit to challenge a request or to accept the challenge.
     *  @param _executionTimeout The time after which the organization will be registered if not challenged.
     *  @param _responseTimeout The time the requester has to answer to challenge.
     *  @param _withdrawTimeout The time the requester has to withdraw his Lif stake.
     *  @param _stakeMultipliers Multipliers of the arbitration cost in basis points (see MULTIPLIER_DIVISOR) as follows:
     *  - The multiplier applied to each party's fee stake for a round when there is no winner/loser in the previous round.
     *  - The multiplier applied to the winner's fee stake for the subsequent round.
     *  - The multiplier applied to the loser's fee stake for the subsequent round.
     */
    function initialize(
        address payable _owner,
        string memory _segment,
        address _orgId,
        address _lif,
        IArbitrator _arbitrator,
        bytes memory _arbitratorExtraData,
        string memory _metaEvidence,
        uint _requesterDeposit,
        uint _challengeBaseDeposit,
        uint _executionTimeout,
        uint _responseTimeout,
        uint _withdrawTimeout,
        uint[3] memory _stakeMultipliers
    ) public initializer {
        require(_owner != address(0), "Directory: Invalid owner address.");
        require(bytes(_segment).length != 0, "Directory: Segment cannot be empty.");
        require(_orgId != address(0), "Directory: Invalid ORG.ID address.");
        require(ERC165Checker._supportsInterface(_orgId, 0x36b78f0f), "Directory: ORG.ID instance has to support ORG.ID interface.");

        emit MetaEvidence(metaEvidenceUpdates, _metaEvidence);
        setInterfaces();
        _transferOwnership(_owner);
        segment = _segment;
        orgId = OrgIdInterface(_orgId);
        changeLifToken(_lif);

        arbitrator = _arbitrator;
        arbitratorExtraData = _arbitratorExtraData;
        requesterDeposit = _requesterDeposit;
        challengeBaseDeposit = _challengeBaseDeposit;
        executionTimeout = _executionTimeout;
        responseTimeout = _responseTimeout;
        withdrawTimeout = _withdrawTimeout;
        sharedStakeMultiplier = _stakeMultipliers[0];
        winnerStakeMultiplier = _stakeMultipliers[1];
        loserStakeMultiplier = _stakeMultipliers[2];

        organizationsIndex[bytes32(0)] = organizations.length;
        organizations.push(bytes32(0));
    }

    /**
     *  @dev Set the list of contract interfaces supported.
     */
    function setInterfaces() public {
        Ownable own;
        DirectoryInterface dir;
        bytes4[4] memory interfaceIds = [
            // ERC165 interface: 0x01ffc9a7
            bytes4(0x01ffc9a7),

            // ownable interface: 0x7f5828d0
            own.owner.selector ^
            own.transferOwnership.selector,

            // directory interface: 0xcc915ab7
            dir.setSegment.selector ^
            dir.getSegment.selector ^
            dir.add.selector ^
            dir.remove.selector ^
            dir.getOrganizations.selector,

            // arbitrable interface: 0x311a6c56
            bytes4(0x311a6c56)
        ];
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            _registerInterface(interfaceIds[i]);
        }
    }

    /**
     *  @dev Allows the owner of the contract to change the segment name.
     *  @param _segment The new segment name.
     */
    function setSegment(string calldata _segment) external onlyOwner {
        require(bytes(_segment).length != 0, "Directory: Segment cannot be empty.");
        emit SegmentChanged(segment, _segment);
        segment = _segment;
    }

    /**
     *  @dev Change Lif token.
     *  @param _lif The new address of the Lif token.
     */
    function changeLifToken(address _lif) public onlyOwner {
        require(_lif != address(0), "Directory: Invalid Lif token address.");
        emit LifTokenChanged(address(lif), _lif);
        lif = IERC20(_lif);
    }

    /** @dev Change the Lif token amount required to make a request.
     *  @param _requesterDeposit The new Lif token amount required to make a request.
     */
    function changeRequesterDeposit(uint _requesterDeposit) external onlyOwner {
        requesterDeposit = _requesterDeposit;
    }

    /** @dev Change the base amount required as a deposit to challenge the organization or to accept the challenge.
     *  @param _challengeBaseDeposit The new base amount of wei required to challenge or to accept the challenge.
     */
    function changeChallengeBaseDeposit(uint _challengeBaseDeposit) external onlyOwner {
        challengeBaseDeposit = _challengeBaseDeposit;
    }

    /** @dev Change the duration of the timeout after which the organization can be registered if not challenged.
     *  @param _executionTimeout The new duration of the execution timeout.
     */
    function changeExecutionTimeout(uint _executionTimeout) external onlyOwner {
        executionTimeout = _executionTimeout;
    }

    /** @dev Change the duration of the time the requester has to accept the challenge.
     *  @param _responseTimeout The new duration of the response timeout.
     */
    function changeResponseTimeout(uint _responseTimeout) external onlyOwner {
        responseTimeout = _responseTimeout;
    }

    /** @dev Change the duration of the time the requester has to withdraw his Lif stake.
     *  @param _withdrawTimeout The new duration of the withdraw timeout.
     */
    function changeWithdrawTimeout(uint _withdrawTimeout) external onlyOwner {
        withdrawTimeout = _withdrawTimeout;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by parties when there is no winner or loser.
     *  @param _sharedStakeMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeSharedStakeMultiplier(uint _sharedStakeMultiplier) external onlyOwner {
        sharedStakeMultiplier = _sharedStakeMultiplier;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by the winner of the previous round.
     *  @param _winnerStakeMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeWinnerStakeMultiplier(uint _winnerStakeMultiplier) external onlyOwner {
        winnerStakeMultiplier = _winnerStakeMultiplier;
    }

    /** @dev Change the proportion of arbitration fees that must be paid as fee stake by the party that lost the previous round.
     *  @param _loserStakeMultiplier Multiplier of arbitration fees that must be paid as fee stake. In basis points.
     */
    function changeLoserStakeMultiplier(uint _loserStakeMultiplier) external onlyOwner {
        loserStakeMultiplier = _loserStakeMultiplier;
    }

    /** @dev Change the arbitrator to be used for disputes that may be raised. The arbitrator is trusted to support appeal periods and not reenter.
     *  @param _arbitrator The new trusted arbitrator to be used in disputes.
     *  @param _arbitratorExtraData The extra data used by the new arbitrator.
     */
    function changeArbitrator(IArbitrator _arbitrator, bytes calldata _arbitratorExtraData) external onlyOwner {
        arbitrator = _arbitrator;
        arbitratorExtraData = _arbitratorExtraData;
    }

    /** @dev Update the meta evidence used for disputes.
     *  @param _metaEvidence The meta evidence to be used for future disputes.
     */
    function changeMetaEvidence(string calldata _metaEvidence) external onlyOwner {
        metaEvidenceUpdates++;
        emit MetaEvidence(metaEvidenceUpdates, _metaEvidence);
    }

    // ****************************** //
    // *   Requests and Challenges  * //
    // ****************************** //

    /** @dev Make a request to add the organization to the directory. Requires a Lif deposit.
     *  @param _organization The ID of the organization.
     *  @param _value The amount of deposited tokens.
     */
    function requestToAdd(bytes32 _organization, uint _value) external {
        Organization storage organization = organizationData[_organization];
        require(organization.status == Status.Absent, "Directory: The organization has wrong status.");
        require(organization.verdict == Verdict.NONE, "Directory: The organization has already been given a verdict.");
        require (_value == requesterDeposit, "Directory: Token value should match the required deposit.");

        // Get the organization info from the ORG.ID registry.
        (bool exist,,,,, address orgOwner, address director, bool orgState, bool directorConfirmed,) = orgId.getOrganization(_organization);

        require(exist, "Directory: Organization not found.");
        require(orgOwner == msg.sender || director == msg.sender, "Directory: Only organization owner or director can add the organization.");
        require(orgState, "Directory: Only enabled organizations can be added.");

        if (director != address(0))
            require(directorConfirmed, "Directory: Only subsidiaries with confirmed director ownership can be added.");

        organization.ID = _organization;
        organization.status = Status.RegistrationRequested;
        organization.requesters.push(msg.sender);
        organization.requestTime = now;
        organization.lastStatusChange = now;
        organization.lif = lif;
        organization.lifStake = _value;
        organization.lif.safeTransferFrom(msg.sender, address(this), _value);
    }

    /** @dev Challenge the organization. Accept enough ETH to cover the deposit, reimburse the rest.
     *  @param _organization The ID of the organization to challenge.
     *  @param _evidence A link to evidence using its URI. Ignored if not provided.
     */
    function challengeRequest(bytes32 _organization, string calldata _evidence) external payable {
        Organization storage organization = organizationData[_organization];
        require(
            organization.status == Status.RegistrationRequested || organization.status == Status.Registered,
            "Directory: The organization should be either registered or registering."
        );
        require(organization.verdict == Verdict.NONE, "Directory: The organization has already been given a verdict.");

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
            emit Evidence(challenge.arbitrator, uint(keccak256(abi.encodePacked(_organization, organization.challenges.length - 1))), msg.sender, _evidence);
    }

    /** @dev Answer to the challenge and create a dispute. Accept enough ETH to cover the deposit, reimburse the rest.
     *  @param _organization The ID of the organization which challenge to accept.
     *  @param _evidence A link to evidence using its URI. Ignored if not provided.
     */
    function acceptChallenge(bytes32 _organization, string calldata _evidence) external payable {
        Organization storage organization = organizationData[_organization];
        require(organization.status == Status.Challenged, "Directory: The organization should be challenged.");
        require(now - organization.lastStatusChange <= responseTimeout, "Directory: Time to accept the challenge has passed.");
        require(
            organization.requesters[organization.requesters.length - 1] == msg.sender,
            "Directory: Only the requester can accept the challenge."
        );

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
        challenge.rounds.length++;
        round.feeRewards = round.feeRewards.subCap(arbitrationCost);

        uint evidenceGroupID = uint(keccak256(abi.encodePacked(_organization, organization.challenges.length - 1)));
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
            // Add the organization if it wasn't already registered.
            if (organizationsIndex[_organization] == 0)
                organization.verdict = Verdict.ADD;
        } else {
            require(now - organization.lastStatusChange > responseTimeout, "Directory: Time to respond to the challenge must pass.");
            organization.status = Status.Absent;
            Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
            challenge.resolved = true;
            uint stake = organization.lifStake;
            organization.lifStake = 0;
            organization.lif.safeTransfer(challenge.challenger, stake);
            // Remove the organization if it was registered.
            if (organizationsIndex[_organization] != 0)
                organization.verdict = Verdict.REMOVE;
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

    /** @dev Withdraw all the Lif tokens deposited when the request was made, and un-register the organization.
     *  @param _organization The ID of the organization to un-register.
     */
    function withdrawTokens(bytes32 _organization) external {
        Organization storage organization = organizationData[_organization];
        require(
            organization.status != Status.Disputed && organization.status != Status.Absent,
            "Directory: The organization has wrong status."
        );
        require(now - organization.requestTime <= withdrawTimeout, "Directory: Time to withdraw tokens has already passed.");
        require(organization.requesters[organization.requesters.length - 1] == msg.sender, "Directory: Only the requester can withdraw tokens.");
        // Close the open challenge if there were any. The challenger will be able to withdraw his deposit.
        if (organization.status == Status.Challenged) {
            Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
            challenge.resolved = true;
        }
        organization.status = Status.Absent;
        uint stake = organization.lifStake;
        organization.lifStake = 0;
        organization.lif.safeTransfer(msg.sender, stake);
        uint256 index = organizationsIndex[_organization];
        if (index != 0) {
            delete organizations[index];
            delete organizationsIndex[_organization];
            emit OrganizationRemoved(_organization);
        }
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
        require(organization.challenges.length > 0, "Directory: The organization was never challenged.");
        Challenge storage challenge = organization.challenges[organization.challenges.length - 1];
        require(!challenge.resolved, "Directory: The challenge must not already be resolved.");

        uint evidenceGroupID = uint(keccak256(abi.encodePacked(_organization, organization.challenges.length - 1)));
        if (bytes(_evidence).length > 0)
            emit Evidence(challenge.arbitrator, evidenceGroupID, msg.sender, _evidence);
    }

    /** @dev Add an organization to the directory. Requires a corresponding verdict from the arbitrator.
     *  @param  _organization The ID of the organization to add.
     *  @return id The ID of the organization.
     */
    function add(bytes32 _organization) external returns (bytes32 id) {
        Organization storage organization = organizationData[_organization];
        require(organization.verdict == Verdict.ADD, "Directory: The organization can't be added without corresponding verdict.");
        organizationsIndex[_organization] = organizations.length;
        organizations.push(_organization);
        organization.verdict = Verdict.NONE;
        emit OrganizationAdded(_organization, organizationsIndex[_organization]);
        return _organization;
    }

    /** @dev Remove an organization from the directory. Requires a corresponding verdict from the arbitrator.
     *  @param  _organization  The ID of the organization to remove.
     */
    function remove(bytes32 _organization) external {
        Organization storage organization = organizationData[_organization];
        require(organization.verdict == Verdict.REMOVE, "Directory: The organization can't be removed without corresponding verdict.");
        uint256 index = organizationsIndex[_organization];
        delete organizations[index];
        delete organizationsIndex[_organization];
        organization.verdict = Verdict.NONE;
        emit OrganizationRemoved(_organization);
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

        // Add the organization if it's not in the directory.
        if (winner == Party.Requester) {
            organization.status = Status.Registered;
            if (organizationsIndex[organization.ID] == 0)
                organization.verdict = Verdict.ADD;
        // Remove the organization if it is in the directory. Send Lif tokens to the challenger.
        } else if (winner == Party.Challenger) {
            organization.status = Status.Absent;
            organization.lifStake = 0;
            organization.lif.safeTransfer(challenge.challenger, stake);
            if (organizationsIndex[organization.ID] != 0)
                organization.verdict = Verdict.REMOVE;
        // 0 ruling. Revert the organization to its default state.
        } else {
            if (organizationsIndex[organization.ID] == 0) {
                organization.status = Status.Absent;
                organization.lifStake = 0;
                organization.lif.safeTransfer(organization.requesters[organization.requesters.length - 1], stake);
            } else
                organization.status = Status.Registered;
        }

        challenge.resolved = true;
        challenge.ruling = Party(_ruling);
    }

    // ************************ //
    // *       Getters        * //
    // ************************ //

    /** @dev Get the name of the segment.
     *  @return The segment name.
     */
    function getSegment() external view returns (string memory) {
        return segment;
    }

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
        for (uint i = 0; i < organizations.length; i++) {
            if (organizations[i] != bytes32(0)) {
                organizationsList[index] = organizations[i];
                index++;
            }
        }
    }

    /** @dev Return organizations array length.
     *  @return count Length of the organizations array.
     */
    function _getOrganizationsCount() internal view returns (uint count) {
        for (uint i = 0; i < organizations.length; i++) {
            if (organizations[i] != bytes32(0))
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

    /** @dev Get the organization info that can't be returned with struct.
     *  @param _organization The ID of the organization.
     *  @return numberOfChallenges Total number of times the organization was challenged.
     *  @return requesters Array of addresses that made a request to add the organization to the directory.
     */
    function getOrgInfo(bytes32 _organization)
        external
        view
        returns (
            uint numberOfChallenges,
            address[] memory requesters
        )
    {
        Organization storage organization = organizationData[_organization];
        return (
            organization.challenges.length,
            organization.requesters
        );
    }

    /** @dev Get the information on a challenge made for the organization.
     *  @param _organization The ID of the organization.
     *  @param _challenge The challenge to query.
     *  @return The challenge information.
     */
    function getChallengeInfo(bytes32 _organization, uint _challenge)
        external
        view
        returns (
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