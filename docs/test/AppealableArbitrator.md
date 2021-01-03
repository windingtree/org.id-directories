## `AppealableArbitrator`



A centralized arbitrator that can be appealed.

### `onlyArbitrator()`





### `requireAppealFee(uint256 _disputeID, bytes _extraData)`






### `constructor(uint256 _arbitrationPrice, contract IArbitrator _arbitrator, bytes _arbitratorExtraData, uint256 _timeOut)` (public)



Constructs the `AppealableArbitrator` contract.


### `changeArbitrator(contract IArbitrator _arbitrator)` (external)



Changes the back up arbitrator.


### `changeTimeOut(uint256 _timeOut)` (external)



Changes the time out.


### `getAppealDisputeID(uint256 _disputeID) → uint256 disputeID` (external)



Gets the specified dispute's latest appeal ID.


### `appeal(uint256 _disputeID, bytes _extraData)` (public)



Appeals a ruling.


### `giveRuling(uint256 _disputeID, uint256 _ruling)` (public)



Gives a ruling.


### `rule(uint256 _disputeID, uint256 _ruling)` (public)



Give a ruling for a dispute. Must be called by the arbitrator.
The purpose of this function is to ensure that the address calling it has the right to rule on the contract.


### `appealCost(uint256 _disputeID, bytes _extraData) → uint256 cost` (public)



Gets the cost of appeal for the specified dispute.


### `disputeStatus(uint256 _disputeID) → enum IArbitrator.DisputeStatus status` (public)



Gets the status of the specified dispute.


### `currentRuling(uint256 _disputeID) → uint256 ruling` (public)



Return the ruling of a dispute.


### `executeRuling(uint256 _disputeID, uint256 _ruling)` (internal)



Executes the ruling of the specified dispute.



