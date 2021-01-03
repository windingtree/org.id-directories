* [DirectoryIndex](#directoryindex)
  * [OwnershipTransferred](#event-ownershiptransferred)
  * [SegmentAdded](#event-segmentadded)
  * [SegmentRemoved](#event-segmentremoved)
  * [addSegment](#function-addsegment)
  * [getSegments](#function-getsegments)
  * [initialize](#function-initialize)
  * [isOwner](#function-isowner)
  * [owner](#function-owner)
  * [removeSegment](#function-removesegment)
  * [renounceOwnership](#function-renounceownership)
  * [segments](#function-segments)
  * [segmentsIndex](#function-segmentsindex)
  * [transferOwnership](#function-transferownership)

# DirectoryIndex

## *event* OwnershipTransferred

DirectoryIndex.OwnershipTransferred(previousOwner, newOwner) `8be0079c`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | previousOwner | indexed |
| *address* | newOwner | indexed |

## *event* SegmentAdded

DirectoryIndex.SegmentAdded(segment, index) `e59c37ea`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | indexed |
| *uint256* | index | indexed |

## *event* SegmentRemoved

DirectoryIndex.SegmentRemoved(segment) `bdbfdd18`

Arguments

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | indexed |


## *function* addSegment

DirectoryIndex.addSegment(segment) `nonpayable` `81dc35d6`

> Adds the directory to the index

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | New segment directory address |


## *function* getSegments

DirectoryIndex.getSegments() `view` `73b789f2`

> Returns registered segments array



Outputs

| **type** | **name** | **description** |
|-|-|-|
| *address[]* | segmentsList | Array of organization Ids |

## *function* initialize

DirectoryIndex.initialize(__owner) `nonpayable` `c4d66de8`

> Initializer for upgradeable contracts.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | __owner | The address of the contract owner |


## *function* isOwner

DirectoryIndex.isOwner() `view` `8f32d59b`

> Returns true if the caller is the current owner.




## *function* owner

DirectoryIndex.owner() `view` `8da5cb5b`

> Returns the address of the current owner.




## *function* removeSegment

DirectoryIndex.removeSegment(segment) `nonpayable` `ab0be362`

> Removes the directory from the index

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | segment | New segment directory address |


## *function* renounceOwnership

DirectoryIndex.renounceOwnership() `nonpayable` `715018a6`

> Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner.     * NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.




## *function* segments

DirectoryIndex.segments() `view` `31560626`


Inputs

| **type** | **name** | **description** |
|-|-|-|
| *uint256* |  | undefined |


## *function* segmentsIndex

DirectoryIndex.segmentsIndex() `view` `ee9427e4`


Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* |  | undefined |


## *function* transferOwnership

DirectoryIndex.transferOwnership(newOwner) `nonpayable` `f2fde38b`

> Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.

Inputs

| **type** | **name** | **description** |
|-|-|-|
| *address* | newOwner | undefined |


---