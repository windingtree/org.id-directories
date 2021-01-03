## `DirectoryIndex`



This smart contract is representing a list of Directories

### `registeredSegment(address segment)`



Throws if segment not found in the index


### `initialize(address payable __owner)` (external)



Initializer for upgradeable contracts.


### `addSegment(address segment)` (external)



Adds the directory to the index


### `removeSegment(address segment)` (external)



Removes the directory from the index


### `getSegments() → address[] segmentsList` (external)



Returns registered segments array


### `_getSegmentsCount() → uint256 count` (internal)



Returns organizations array length



### `SegmentAdded(address segment, uint256 index)`



Event triggered when a segment is added to the index

### `SegmentRemoved(address segment)`



Event triggered when a segment address is removed from the index

