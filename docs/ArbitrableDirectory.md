## `ArbitrableDirectory`



A Directory contract arbitrated by Kleros.
Organizations are added or removed based on a ruling given by the arbitrator contract.
NOTE: This contract trusts that the Arbitrator is honest and will not reenter or modify its costs during a call.
The arbitrator must support appeal period.

### `onlyGovernor()`






### `initialize(address _governor, string _segment, contract OrgIdInterface _orgId, contract ERC20 _lif, contract IArbitrator _arbitrator, bytes _arbitratorExtraData, string _metaEvidence, uint256 _requesterDeposit, uint256 _challengeBaseDeposit, uint256 _executionTimeout, uint256 _responseTimeout, uint256 _withdrawTimeout, uint256[3] _stakeMultipliers)` (public)



Initializer for upgradeable contracts.


### `setSegment(string _segment)` (external)



Allows the governor of the contract to change the segment name.


### `changeRequesterDeposit(uint256 _requesterDeposit)` (external)



Change the Lif token amount required to make a request.


### `changeChallengeBaseDeposit(uint256 _challengeBaseDeposit)` (external)



Change the base amount required as a deposit to challenge the organization or to accept the challenge.


### `changeExecutionTimeout(uint256 _executionTimeout)` (external)



Change the duration of the timeout after which the organization can be registered if not challenged.


### `changeResponseTimeout(uint256 _responseTimeout)` (external)



Change the duration of the time the requester has to accept the challenge.


### `changeWithdrawTimeout(uint256 _withdrawTimeout)` (external)



Change the duration of the time after which it becomes possible to execute the withdrawal request.


### `changeSharedStakeMultiplier(uint256 _sharedStakeMultiplier)` (external)



Change the proportion of arbitration fees that must be paid as fee stake by parties when there is no winner or loser.


### `changeWinnerStakeMultiplier(uint256 _winnerStakeMultiplier)` (external)



Change the proportion of arbitration fees that must be paid as fee stake by the winner of the previous round.


### `changeLoserStakeMultiplier(uint256 _loserStakeMultiplier)` (external)



Change the proportion of arbitration fees that must be paid as fee stake by the party that lost the previous round.


### `changeArbitrator(contract IArbitrator _arbitrator, bytes _arbitratorExtraData)` (external)



Change the arbitrator to be used for disputes that may be raised. The arbitrator is trusted to support appeal periods and not reenter.


### `changeMetaEvidence(string _metaEvidence)` (external)



Update the meta evidence used for disputes.


### `requestToAdd(bytes32 _organization)` (external)



Make a request to add an organization to the directory. Requires a Lif deposit.


### `challengeOrganization(bytes32 _organization, string _evidence)` (external)



Challenge the organization. Accept enough ETH to cover the deposit, reimburse the rest.


### `acceptChallenge(bytes32 _organization, string _evidence)` (external)



Answer to the challenge and create a dispute. Accept enough ETH to cover the deposit, reimburse the rest.


### `executeTimeout(bytes32 _organization)` (external)



Execute an unchallenged request if the execution timeout has passed, or execute the challenge if it wasn't accepted during response timeout.


### `fundAppeal(bytes32 _organization, enum ArbitrableDirectory.Party _side)` (external)



Take up to the total amount required to fund a side of an appeal. Reimburse the rest. Create an appeal if both sides are fully funded.


### `withdrawFeesAndRewards(address payable _beneficiary, bytes32 _organization, uint256 _challenge, uint256 _round)` (external)



Reimburse contributions if no disputes were raised. If a dispute was raised, send the fee stake rewards and reimbursements proportionally to the contributions made to the winner of a dispute.


### `withdrawFeesAndRewardsTotal(address payable _beneficiary, bytes32 _organization, uint256 _challenge)` (external)



Reimburse contributions if no disputes were raised. If a dispute was raised, send the fee stake rewards and reimbursements proportionally to the contributions made to the winner of a dispute.


### `makeWithdrawalRequest(bytes32 _organization)` (external)



Make a request to remove the organization and withdraw Lif tokens from the directory. The organization is removed right away but the tokens can only be withdrawn after withdrawTimeout, to prevent frontrunning the challengers.


### `withdrawTokens(bytes32 _organization)` (external)



Withdraw all the Lif tokens deposited when the request was made.


### `rule(uint256 _disputeID, uint256 _ruling)` (public)



Give a ruling for a dispute. Can only be called by the arbitrator. TRUSTED.
Accounts for the situation where the winner loses a case due to paying less appeal fees than expected.


### `submitEvidence(bytes32 _organization, string _evidence)` (external)



Submit a reference to evidence. EVENT.


### `getCertainOrganizations(uint256 _cursor, uint256 _count, bool returnRequested) → bytes32[] organizationsList` (internal)



Get all the registered or requested organizations.


### `getCertainOrganizationsCount(uint256 _cursor, uint256 _count, bool returnRequested) → uint256 count` (internal)



Return registeredOrganizations array length.


### `removeFromIndex(bytes32 _organization, bool removeRequested)` (internal)



Remove organization from the storage


### `calculateContribution(uint256 _available, uint256 _requiredAmount) → uint256 taken, uint256 remainder` (internal)



Return the contribution value and remainder from available ETH and required amount.


### `contribute(struct ArbitrableDirectory.Round _round, enum ArbitrableDirectory.Party _side, address payable _contributor, uint256 _amount, uint256 _totalRequired, bytes32 _organization) → uint256` (internal)



Make a fee contribution.


### `setInterfaces()` (internal)



Set the list of contract interfaces supported

### `executeRuling(uint256 _disputeID, uint256 _ruling)` (internal)



Execute the ruling of a dispute.


### `calculateFeesAndRewards(address payable _beneficiary, struct ArbitrableDirectory.Challenge challenge, struct ArbitrableDirectory.Round round) → uint256 reward` (internal)



Calculate fees and rewards for the beneficiary


### `getSegment() → string` (public)



Returns a segment name.

### `getOrganizations(uint256 _cursor, uint256 _count) → bytes32[] organizationsList` (external)



Get all the registered organizations.


### `getOrganizationsCount(uint256 _cursor, uint256 _count) → uint256 count` (public)



Return registeredOrganizations array length.


### `getRequestedOrganizations(uint256 _cursor, uint256 _count) → bytes32[] organizationsList` (external)



Get all the requested organizations.


### `getRequestedOrganizationsCount(uint256 _cursor, uint256 _count) → uint256 count` (public)



Return registeredOrganizations array length.


### `getContributions(bytes32 _organization, uint256 _challenge, uint256 _round, address _contributor) → uint256[3] contributions` (external)



Get the contributions made by a party for a given round of a challenge.


### `getNumberOfChallenges(bytes32 _organization) → uint256 numberOfChallenges` (external)



Get the number of challenges of the organization.


### `getNumberOfDisputes(bytes32 _organization) → uint256 numberOfDisputes` (external)



Get the number of ongoing disputes of the organization.


### `getChallengeInfo(bytes32 _organization, uint256 _challenge) → bool disputed, uint256 disputeID, bool resolved, address payable challenger, uint256 numberOfRounds, enum ArbitrableDirectory.Party ruling, contract IArbitrator arbitrator, bytes arbitratorExtraData, uint256 metaEvidenceID` (external)



Get the information of a challenge made for the organization.


### `getRoundInfo(bytes32 _organization, uint256 _challenge, uint256 _round) → bool appealed, uint256[3] paidFees, bool[3] hasPaid, uint256 feeRewards` (external)



Get the information of a round of a challenge.


### `getFeesAndRewards(address payable _beneficiary, bytes32 _organization, uint256 _challenge, uint256 _round) → uint256 reward` (public)



Return amount of beneficiary's reward


### `getFeesAndRewardsTotal(address payable _beneficiary, bytes32 _organization, uint256 _challenge) → uint256 reward` (public)



Return amount of beneficiary's reward



### `SegmentChanged(string _previousSegment, string _newSegment)`



Event triggered every time segment value is changed.


### `OrganizationSubmitted(bytes32 _organization)`



Event triggered when a request to add an organization is made.


### `OrganizationAdded(bytes32 _organization, uint256 _index)`



Event triggered every time organization is added.


### `OrganizationRemoved(bytes32 _organization)`



Event triggered every time organization is removed.


### `OrganizationRequestRemoved(bytes32 _organization)`



Event triggered every time organization request is removed.


### `OrganizationChallenged(bytes32 _organization, address _challenger, uint256 _challenge)`



Event triggered every time organization is challenged.


### `ChallengeContributed(bytes32 _organization, uint256 _challenge, address _contributor)`



Event triggered every time challenge is contributed.


