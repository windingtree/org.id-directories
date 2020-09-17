// SPDX-License-Identifier: GPL-3.0-only;
pragma solidity 0.5.17;

/**
 * @title DirectoryInterface
 */
contract DirectoryInterface {

    /**
     * @dev Returns a segment name.
     */
    function getSegment() public view returns (string memory);

    /**
     * @dev Returns registered organizations array
     * @return {
         "organizationsList": "Array of organization Ids"
     }
     */
    function getOrganizations(uint _cursor, uint _count)
        external
        view
        returns (bytes32[] memory organizationsList);

    /**
     * @dev Returns organizations array length
     * @return {
         "count": "Length of the organizations array"
     }
     */
    function getOrganizationsCount(uint _cursor, uint _count)
        public
        view
        returns (uint256 count);
}
