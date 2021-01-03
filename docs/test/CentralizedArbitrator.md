## `CentralizedArbitrator`



This is a centralized arbitrator deciding alone on the result of disputes. No appeals are possible.

### `onlyOwner()`





### `requireArbitrationFee(bytes _extraData)`






### `constructor(uint256 _arbitrationPrice)` (public)



Constructor. Set the initial arbitration price.


### `setArbitrationPrice(uint256 _arbitrationPrice)` (public)



Set the arbitration price. Only callable by the owner.


### `arbitrationCost(bytes _extraData) → uint256 fee` (public)



Cost of arbitration. Accessor to arbitrationPrice.


### `appealCost(uint256 _disputeID, bytes _extraData) → uint256 fee` (public)



Cost of appeal. Since it is not possible, it's a high value which can never be paid.


### `createDispute(uint256 _choices, bytes _extraData) → uint256 disputeID` (public)



Create a dispute. Must be called by the arbitrable contract.
Must be paid at least arbitrationCost().


### `_giveRuling(uint256 _disputeID, uint256 _ruling)` (internal)



Give a ruling. UNTRUSTED.


### `giveRuling(uint256 _disputeID, uint256 _ruling)` (public)



Give a ruling. UNTRUSTED.


### `disputeStatus(uint256 _disputeID) → enum IArbitrator.DisputeStatus status` (public)



Return the status of a dispute.


### `currentRuling(uint256 _disputeID) → uint256 ruling` (public)



Return the ruling of a dispute.



