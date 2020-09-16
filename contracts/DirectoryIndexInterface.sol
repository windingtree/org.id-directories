// SPDX-License-Identifier: GPL-3.0-only;
pragma solidity 0.5.17;

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
