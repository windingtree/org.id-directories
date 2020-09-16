// SPDX-License-Identifier: GPL-3.0-only;
pragma solidity 0.5.17;

contract ArbitrableDirectoryInterface {

    /**
     *  @dev Allows the governor of the contract to change the segment name.
     *  @param _segment The new segment name.
     */
    function setSegment(string calldata _segment) external;

    /** @dev Make a request to add an organization to the directory. Requires a Lif deposit.
     *  @param _organization The ID of the organization.
     */
    function requestToAdd(bytes32 _organization) external;

    /** @dev Challenge the organization. Accept enough ETH to cover the deposit, reimburse the rest.
     *  @param _organization The ID of the organization to challenge.
     *  @param _evidence A link to evidence using its URI. Ignored if not provided.
     */
    function challengeOrganization(bytes32 _organization, string calldata _evidence) external payable;

    /** @dev Answer to the challenge and create a dispute. Accept enough ETH to cover the deposit, reimburse the rest.
     *  @param _organization The ID of the organization which challenge to accept.
     *  @param _evidence A link to evidence using its URI. Ignored if not provided.
     */
    function acceptChallenge(bytes32 _organization, string calldata _evidence) external payable;

    /** @dev Execute an unchallenged request if the execution timeout has passed, or execute the challenge if it wasn't accepted during response timeout.
     *  @param _organization The ID of the organization.
     */
    function executeTimeout(bytes32 _organization) external;

    /** @dev Take up to the total amount required to fund a side of an appeal. Reimburse the rest. Create an appeal if both sides are fully funded.
     *  @param _organization The ID of the organization.
     *  @param _side The recipient of the contribution.
     */

    /** @dev Submit a reference to evidence. EVENT.
     *  @param _organization The ID of the organization which the evidence is related to.
     *  @param _evidence A link to evidence using its URI.
     */
    function submitEvidence(bytes32 _organization, string calldata _evidence) external;

    /** @dev Get all the registered organizations.
     *  @param _cursor Index of the organization from which to start querying.
     *  @param _count Number of organizations to go through. Iterates until the end if set to "0" or number higher than the total number of organizations.
     *  @return organizationsList Array of organization IDs.
     */
    function getOrganizations(uint _cursor, uint _count)
        external
        view
        returns (bytes32[] memory organizationsList);
}