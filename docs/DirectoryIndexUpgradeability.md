* [DirectoryIndexUpgradeability](#directoryindexupgradeability)
  * [OwnershipTransferred](#event-ownershiptransferred)
  * [SegmentAdded](#event-segmentadded)
  * [SegmentRemoved](#event-segmentremoved)
  * [addSegment](#function-addsegment)
  * [getSegments](#function-getsegments)
  * [initialize](#function-initialize)
  * [isOwner](#function-isowner)
  * [newFunction](#function-newfunction)
  * [owner](#function-owner)
  * [removeSegment](#function-removesegment)
  * [renounceOwnership](#function-renounceownership)
  * [segments](#function-segments)
  * [segmentsIndex](#function-segmentsindex)
  * [setupNewStorage](#function-setupnewstorage)
  * [test](#function-test)
  * [transferOwnership](#function-transferownership)

# DirectoryIndexUpgradeability

## *event* OwnershipTransferred

DirectoryIndexUpgradeability.OwnershipTransferred(previousOwner, newOwner) `8be0079c`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | previousOwner | indexed |
| *address* | newOwner | indexed |

## *event* SegmentAdded

DirectoryIndexUpgradeability.SegmentAdded(segment, index) `e59c37ea`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | indexed |
| *uint256* | index | indexed |

## *event* SegmentRemoved

DirectoryIndexUpgradeability.SegmentRemoved(segment) `bdbfdd18`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | indexed |


## *function* addSegment

DirectoryIndexUpgradeability.addSegment(segment) `nonpayable` `81dc35d6`

> Adds the directory to the index

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | New segment directory address |


## *function* getSegments

DirectoryIndexUpgradeability.getSegments() `view` `73b789f2`

> Returns registered segments array



Outputs

| **type** | **name** | **description** |
|-|-|-|
| *address[]* | segmentsList | Array of organization Ids |

## *function* initialize

DirectoryIndexUpgradeability.initialize(__owner) `nonpayable` `c4d66de8`

> Initializer for upgradeable contracts.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | __owner | The address of the contract owner |


## *function* isOwner

DirectoryIndexUpgradeability.isOwner() `view` `8f32d59b`

> Returns true if the caller is the current owner.




## *function* newFunction

DirectoryIndexUpgradeability.newFunction() `view` `1b28d63e`





## *function* owner

DirectoryIndexUpgradeability.owner() `view` `8da5cb5b`

> Returns the address of the current owner.




## *function* removeSegment

DirectoryIndexUpgradeability.removeSegment(segment) `nonpayable` `ab0be362`

> Removes the directory from the index

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | New segment directory address |


## *function* renounceOwnership

DirectoryIndexUpgradeability.renounceOwnership() `nonpayable` `715018a6`

> Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner.     * NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.




## *function* segments

DirectoryIndexUpgradeability.segments() `view` `31560626`


Inputs

| **type** | **name** | **description** |
|-|-|-|
| *uint256* |  | undefined |


## *function* segmentsIndex

DirectoryIndexUpgradeability.segmentsIndex() `view` `ee9427e4`


Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* |  | undefined |


## *function* setupNewStorage

DirectoryIndexUpgradeability.setupNewStorage(value) `nonpayable` `00551333`


Inputs

| **type** | **name** | **description** |
|-|-|-|
| *uint256* | value | undefined |


## *function* test

DirectoryIndexUpgradeability.test() `view` `f8a8fd6d`





## *function* transferOwnership

DirectoryIndexUpgradeability.transferOwnership(newOwner) `nonpayable` `f2fde38b`

> Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | newOwner | undefined |


---