pragma solidity >=0.5.16;

import "openzeppelin-solidity/contracts/introspection/ERC165Checker.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./DirectoryIndexInterface.sol";
import "./DirectoryInterface.sol";

/**
 * @title DirectoryIndex
 * @dev This smart contract is representing a list of Directories
 */
contract DirectoryIndex is Ownable, DirectoryIndexInterface, Initializable {

    using SafeMath for uint256;

    // List of registered segments
    address[] public segments;

    // Mapping of segments directory address to index in the directories list
    mapping(address => uint256) public segmentsIndex;

    /**
     * @dev Event triggered when a segment is added to the index
     */
    event SegmentAdded(address indexed segment, uint256 indexed index);

    /**
     * @dev Event triggered when a segment address is removed from the index
     */
    event SegmentRemoved(address indexed segment);

    /**
     * @dev Throws if segment not found in the index
     */
    modifier registeredSegment(address segment) {
        require(
            segmentsIndex[segment] != 0,
            "DirecttoryIndex: Segment with given address on found"
        );
        _;
    }

    /**
     * @dev Initializer for upgradeable contracts.
     * @param __owner The address of the contract owner
     */
    function initialize(address payable __owner) external initializer {
        require(__owner != address(0), 'DirectoryIndex: Invalid owner address');
        _transferOwnership(__owner);
        segmentsIndex[address(0)] = segments.length;
        segments.push(address(0));
    }

    /**
     * @dev Adds the directory to the index
     * @param segment New segment directory address
     */
    function addSegment(address segment) external onlyOwner {
        require(
            segment != address(0),
            'DirectoryIndex: Invalid segment address'
        );
        require(
            ERC165Checker._supportsInterface(segment, 0xcc915ab7),
            "DirectoryIndex: Segment has to support directory interface"
        );

        segmentsIndex[segment] = segments.length;
        segments.push(segment);

        emit SegmentAdded(segment, segmentsIndex[segment]);
    }

    /**
     * @dev Removes the directory from the index
     * @param segment New segment directory address
     */
    function removeSegment(address segment)
        external
        onlyOwner 
        registeredSegment(segment)
    {
        uint256 index = segmentsIndex[segment];
        delete segments[index];
        delete segmentsIndex[segment];

        emit SegmentRemoved(segment);
    }

    /**
     * @dev Returns registered segments array
     * @return {
         "segmentsList": "Array of organization Ids"
     }
     */
    function getSegments() 
        external 
        view 
        returns (address[] memory segmentsList) 
    {
        segmentsList = new address[](_getSegmentsCount());
        uint256 index;

        for (uint256 i = 0; i < segments.length; i++) {

            if (segments[i] != address(0)) {

                segmentsList[index] = segments[i];
                index = index.add(1);
            }
        }
    }

    /**
     * @dev Returns organizations array length
     * @return {
         "count": "Length of the organizations array"
     }
     */
    function _getSegmentsCount() internal view returns (uint256 count) {
        
        for (uint256 i = 0; i < segments.length; i++) {

            if (segments[i] != address(0)) {
                
                count = count.add(1);
            }
        }
    }
}
