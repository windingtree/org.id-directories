pragma solidity >=0.5.16;

contract DirectoryIndexInterface {

    /**
     * @dev Adds the directory to the index
     * @param segment New segment directory address
     */
    function addSegment(address segment) external;

    /**
     * @dev Removes the directory from the index
     * @param segment New segment directory address
     */
    function removeSegment(address segment) external;

    /**
     * @dev Returns address of a segment
     * is unknown.
     * @param segment Segment name
     * @return {
         "addr": "Address of a segment"
     }
     */
    function getSegment(address segment) external view returns(address addr);

    /**
     * @dev Returns registered segments array
     * @return {
         "segmentsList": "Array of organization Ids"
     }
     */
    function getSegments() 
        external 
        view 
        returns (address[] memory segmentsList);
}
