## `Directory`



A Directory that can handle a list of organizations sharing a
common segment such as hotels, airlines etc.

### `registeredOrganization(bytes32 id)`



Throws if organization not found in the index


### `initialize(address payable __owner, string _segment, address _orgId)` (public)



Initializer for upgradeable contracts.


### `setSegment(string _segment)` (external)



Allows the owner of the contract to change the
segment name.


### `add(bytes32 organization) → bytes32 id` (external)



Adds an organization to the registry


### `remove(bytes32 organization)` (external)



Removes the organization from the registry


### `getOrganizations(uint256 _cursor, uint256 _count) → bytes32[] organizationsList` (external)



Get all the registered organizations.


### `getSegment() → string` (public)



Returns a segment name.

### `getOrganizationsCount(uint256 _cursor, uint256 _count) → uint256 count` (public)



Return registeredOrganizations array length.


### `setInterfaces()` (internal)



Set the list of contract interfaces supported

### `_addOrganization(bytes32 organization) → bytes32` (internal)



Add new organization in the directory.
Only organizations that conform to OrganizationInterface can be added.
ERC165 method of interface checking is used.

Emits `OrganizationAdded` on success.


### `_removeOrganization(bytes32 organization)` (internal)



Allows a owner to remove an organization
from the directory. Does not destroy the organization contract.
Emits `OrganizationRemoved` on success.



### `SegmentChanged(string previousSegment, string newSegment)`



Event triggered every time segment value is changed

### `OrganizationAdded(bytes32 organization, uint256 index)`



Event triggered every time organization is added.

### `OrganizationRemoved(bytes32 organization)`



Event triggered every time organization is removed.

