// SPDX-License-Identifier: GPL-3.0-only;
pragma solidity 0.5.17;

/**
 * @title DirectoryInterface
 * @dev Usable in libraries. Directory is essentially a list
 * of 0xORG smart contracts that share a common segment - hotels, airlines, otas.
 */
contract DirectoryInterface {

    /**
     * @dev Allows the owner of the contract to change the
     * segment name.
     * @param _segment The new segment name
     */
    function setSegment(string calldata _segment) external;

    /**
     * @dev Adds the organization to the registry
     * @param  organization Organization"s Id
     * @return {
         "id": "The organization Id"
     }
     */
    function add(bytes32 organization) external returns (bytes32 id);

    /**
     * @dev Removes the organization from the registry
     * @param  organization  Organization"s Id
     */
    function remove(bytes32 organization) external;

    /**
     * @dev Returns registered organizations array
     * @return {
         "organizationsList": "Array of organization Ids"
     }
     */
    function getOrganizations()
        external
        view
        returns (bytes32[] memory organizationsList);
}
