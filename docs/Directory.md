* [Directory](#directory)
  * [OrganizationAdded](#event-organizationadded)
  * [OrganizationRemoved](#event-organizationremoved)
  * [OwnershipTransferred](#event-ownershiptransferred)
  * [SegmentChanged](#event-segmentchanged)
  * [add](#function-add)
  * [getOrganizations](#function-getorganizations)
  * [getSegment](#function-getsegment)
  * [initialize](#function-initialize)
  * [isOwner](#function-isowner)
  * [orgId](#function-orgid)
  * [owner](#function-owner)
  * [remove](#function-remove)
  * [renounceOwnership](#function-renounceownership)
  * [setInterfaces](#function-setinterfaces)
  * [setSegment](#function-setsegment)
  * [supportsInterface](#function-supportsinterface)
  * [transferOwnership](#function-transferownership)

# Directory

## *event* OrganizationAdded

Directory.OrganizationAdded(organization, index) `df99887c`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | indexed |
| *uint256* | index | not indexed |

## *event* OrganizationRemoved

Directory.OrganizationRemoved(organization) `01a059e8`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | indexed |

## *event* OwnershipTransferred

Directory.OwnershipTransferred(previousOwner, newOwner) `8be0079c`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | previousOwner | indexed |
| *address* | newOwner | indexed |

## *event* SegmentChanged

Directory.SegmentChanged(previousSegment, newSegment) `470f6531`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *string* | previousSegment | not indexed |
| *string* | newSegment | not indexed |


## *function* add

Directory.add(organization) `nonpayable` `446bffba`

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

Directory.getOrganizations() `view` `9754a3a8`

> Returns registered organizations array



Outputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32[]* | organizationsList | Array of organization Ids |

## *function* getSegment

Directory.getSegment() `view` `2203793c`

> Returns the segment name




## *function* initialize

Directory.initialize(__owner, _segment, _orgId) `nonpayable` `7bb7c0d8`

> Initializer for upgradeable contracts.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | __owner | The address of the contract owner |
| *string* | _segment | The segment name |
| *address* | _orgId | undefined |


## *function* isOwner

Directory.isOwner() `view` `8f32d59b`

> Returns true if the caller is the current owner.




## *function* orgId

Directory.orgId() `view` `1730bdfe`





## *function* owner

Directory.owner() `view` `8da5cb5b`

> Returns the address of the current owner.




## *function* remove

Directory.remove(organization) `nonpayable` `95bc2673`

> Removes the organization from the registry

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | Organization"s Id |


## *function* renounceOwnership

Directory.renounceOwnership() `nonpayable` `715018a6`

> Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner.     * NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.




## *function* setInterfaces

Directory.setInterfaces() `nonpayable` `fca85eb3`

> Set the list of contract interfaces supported




## *function* setSegment

Directory.setSegment(_segment) `nonpayable` `a81159ea`

> Allows the owner of the contract to change the segment name.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *string* | _segment | The new segment name |


## *function* supportsInterface

Directory.supportsInterface(interfaceId) `view` `01ffc9a7`

> See {IERC165-supportsInterface}.     * Time complexity O(1), guaranteed to always use less than 30 000 gas.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes4* | interfaceId | undefined |


## *function* transferOwnership

Directory.transferOwnership(newOwner) `nonpayable` `f2fde38b`

> Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | newOwner | undefined |


---