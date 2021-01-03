* [DirectoryUpgradeability](#directoryupgradeability)
  * [OrganizationAdded](#event-organizationadded)
  * [OrganizationRemoved](#event-organizationremoved)
  * [OwnershipTransferred](#event-ownershiptransferred)
  * [SegmentChanged](#event-segmentchanged)
  * [add](#function-add)
  * [getOrganizations](#function-getorganizations)
  * [getSegment](#function-getsegment)
  * [initialize](#function-initialize)
  * [initialize](#function-initialize)
  * [isOwner](#function-isowner)
  * [newFunction](#function-newfunction)
  * [orgId](#function-orgid)
  * [owner](#function-owner)
  * [remove](#function-remove)
  * [renounceOwnership](#function-renounceownership)
  * [setInterfaces](#function-setinterfaces)
  * [setSegment](#function-setsegment)
  * [setupNewStorage](#function-setupnewstorage)
  * [supportsInterface](#function-supportsinterface)
  * [test](#function-test)
  * [transferOwnership](#function-transferownership)

# DirectoryUpgradeability

## *event* OrganizationAdded

DirectoryUpgradeability.OrganizationAdded(organization, index) `df99887c`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | indexed |
| *uint256* | index | not indexed |

## *event* OrganizationRemoved

DirectoryUpgradeability.OrganizationRemoved(organization) `01a059e8`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | indexed |

## *event* OwnershipTransferred

DirectoryUpgradeability.OwnershipTransferred(previousOwner, newOwner) `8be0079c`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | previousOwner | indexed |
| *address* | newOwner | indexed |

## *event* SegmentChanged

DirectoryUpgradeability.SegmentChanged(previousSegment, newSegment) `470f6531`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *string* | previousSegment | not indexed |
| *string* | newSegment | not indexed |


## *function* add

DirectoryUpgradeability.add(organization) `nonpayable` `446bffba`

> Adds an organization to the registry

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | Organization"s Id |

Outputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | id | The organization Id |

## *function* getOrganizations

DirectoryUpgradeability.getOrganizations() `view` `9754a3a8`

> Returns registered organizations array



Outputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32[]* | organizationsList | Array of organization Ids |

## *function* getSegment

DirectoryUpgradeability.getSegment() `view` `2203793c`

> Returns the segment name




## *function* initialize

DirectoryUpgradeability.initialize(__owner, _segment, _orgId) `nonpayable` `7bb7c0d8`

> Initializer for upgradeable contracts.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | __owner | The address of the contract owner |
| *string* | _segment | The segment name |
| *address* | _orgId | undefined |


## *function* initialize

DirectoryUpgradeability.initialize() `nonpayable` `8129fc1c`





## *function* isOwner

DirectoryUpgradeability.isOwner() `view` `8f32d59b`

> Returns true if the caller is the current owner.




## *function* newFunction

DirectoryUpgradeability.newFunction() `view` `1b28d63e`





## *function* orgId

DirectoryUpgradeability.orgId() `view` `1730bdfe`





## *function* owner

DirectoryUpgradeability.owner() `view` `8da5cb5b`

> Returns the address of the current owner.




## *function* remove

DirectoryUpgradeability.remove(organization) `nonpayable` `95bc2673`

> Removes the organization from the registry

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | Organization"s Id |


## *function* renounceOwnership

DirectoryUpgradeability.renounceOwnership() `nonpayable` `715018a6`

> Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner.     * NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.




## *function* setInterfaces

DirectoryUpgradeability.setInterfaces() `nonpayable` `fca85eb3`

> Set the list of contract interfaces supported




## *function* setSegment

DirectoryUpgradeability.setSegment(_segment) `nonpayable` `a81159ea`

> Allows the owner of the contract to change the segment name.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *string* | _segment | The new segment name |


## *function* setupNewStorage

DirectoryUpgradeability.setupNewStorage(value) `nonpayable` `00551333`


Inputs

| **type** | **name** | **description** |
|-|-|-|
| *uint256* | value | undefined |


## *function* supportsInterface

DirectoryUpgradeability.supportsInterface(interfaceId) `view` `01ffc9a7`

> See {IERC165-supportsInterface}.     * Time complexity O(1), guaranteed to always use less than 30 000 gas.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes4* | interfaceId | undefined |


## *function* test

DirectoryUpgradeability.test() `view` `f8a8fd6d`





## *function* transferOwnership

DirectoryUpgradeability.transferOwnership(newOwner) `nonpayable` `f2fde38b`

> Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | newOwner | undefined |


---