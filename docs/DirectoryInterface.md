* [DirectoryInterface](#directoryinterface)
  * [OwnershipTransferred](#event-ownershiptransferred)
  * [add](#function-add)
  * [getOrganizations](#function-getorganizations)
  * [getSegment](#function-getsegment)
  * [isOwner](#function-isowner)
  * [owner](#function-owner)
  * [remove](#function-remove)
  * [renounceOwnership](#function-renounceownership)
  * [setSegment](#function-setsegment)
  * [transferOwnership](#function-transferownership)

# DirectoryInterface

## *event* OwnershipTransferred

DirectoryInterface.OwnershipTransferred(previousOwner, newOwner) `8be0079c`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | previousOwner | indexed |
| *address* | newOwner | indexed |


## *function* add

DirectoryInterface.add(organization) `nonpayable` `446bffba`

> Adds the organization to the registry

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | Organization"s Id |

Outputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | id | The organization Id |

## *function* getOrganizations

DirectoryInterface.getOrganizations() `view` `9754a3a8`

> Returns registered organizations array



Outputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32[]* | organizationsList | Array of organization Ids |

## *function* getSegment

DirectoryInterface.getSegment() `view` `2203793c`

> Returns the segment name




## *function* isOwner

DirectoryInterface.isOwner() `view` `8f32d59b`

> Returns true if the caller is the current owner.




## *function* owner

DirectoryInterface.owner() `view` `8da5cb5b`

> Returns the address of the current owner.




## *function* remove

DirectoryInterface.remove(organization) `nonpayable` `95bc2673`

> Removes the organization from the registry

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *bytes32* | organization | Organization"s Id |


## *function* renounceOwnership

DirectoryInterface.renounceOwnership() `nonpayable` `715018a6`

> Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner.     * NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.




## *function* setSegment

DirectoryInterface.setSegment(_segment) `nonpayable` `a81159ea`

> Allows the owner of the contract to change the segment name.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *string* | _segment | The new segment name |


## *function* transferOwnership

DirectoryInterface.transferOwnership(newOwner) `nonpayable` `f2fde38b`

> Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | newOwner | undefined |


---