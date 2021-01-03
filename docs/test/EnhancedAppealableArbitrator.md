## `EnhancedAppealableArbitrator`



Implementation of `AppealableArbitrator` that supports `appealPeriod`.


### `constructor(uint256 _arbitrationPrice, contract IArbitrator _arbitrator, bytes _arbitratorExtraData, uint256 _timeOut)` (public)



Constructs the `EnhancedAppealableArbitrator` contract.


### `appealPeriod(uint256 _disputeID) → uint256 start, uint256 end` (public)



Compute the start and end of the dispute's current or next appeal period, if possible.



