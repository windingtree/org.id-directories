// SPDX-License-Identifier: GPL-3.0-only;
pragma solidity 0.5.17;

import "@openzeppelin/contracts/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@windingtree/org.id/contracts/ERC165/ERC165.sol";
import "@windingtree/org.id/contracts/OrgIdInterface.sol";
import "./DirectoryInterface.sol";

/**
 * @title Directory
 * @dev A Directory that can handle a list of organizations sharing a
 * common segment such as hotels, airlines etc.
 */
contract Directory is DirectoryInterface, Ownable, ERC165, Initializable {

    using SafeMath for uint256;

    // An instance of the ORG.ID smart contract
    OrgIdInterface public orgId;

    // Segment name, i. e. hotel, airline
    string internal segment;

    // Array of addresses of `Organization` contracts
    bytes32[] public registeredOrganizations;

    // Mapping of organizations position in the general organization index
    mapping(bytes32 => uint256) internal organizationsIndex;

    /**
     * @dev Event triggered every time segment value is changed
     */
    event SegmentChanged(string previousSegment, string newSegment);

    /**
     * @dev Event triggered every time organization is added.
     */
    event OrganizationAdded(bytes32 indexed organization, uint256 index);

    /**
     * @dev Event triggered every time organization is removed.
     */
    event OrganizationRemoved(bytes32 indexed organization);

    /**
     * @dev Throws if organization not found in the index
     */
    modifier registeredOrganization(bytes32 id) {
        require(
            organizationsIndex[id] != 0,
            "Directory: Organization with given Id not found"
        );
        _;
    }

    /**
     * @dev Initializer for upgradeable contracts.
     * @param __owner The address of the contract owner
     * @param _segment The segment name
     */
    function initialize(
        address payable __owner,
        string memory _segment,
        address _orgId
    ) public initializer {
        require(
            __owner != address(0),
            "Directory: Invalid owner address"
        );
        require(
            bytes(_segment).length != 0,
            "Directory: Segment cannot be empty"
        );
        require(
            _orgId != address(0),
            "Directory: Invalid ORG.ID address"
        );
        require(
            ERC165Checker._supportsInterface(_orgId, 0x0f4893ef),
            "Directory: ORG.ID instance has to support ORG.ID interface"
        );

        setInterfaces();
        _transferOwnership(__owner);
        orgId = OrgIdInterface(_orgId);
        segment = _segment;
        organizationsIndex[bytes32(0)] = registeredOrganizations.length;
        registeredOrganizations.push(bytes32(0));
    }

    /**
     * @dev Allows the owner of the contract to change the
     * segment name.
     * @param _segment The new segment name
     */
    function setSegment(string calldata _segment) external onlyOwner {
        require(
            bytes(_segment).length != 0,
            "Directory: Segment cannot be empty"
        );
        emit SegmentChanged(segment, _segment);
        segment = _segment;
    }

    /**
     * @dev Adds an organization to the registry
     * @param  organization Organization"s Id
     * @return {
         "id": "The organization Id"
     }
     */
    function add(bytes32 organization) external returns (bytes32 id) {
        id = _addOrganization(organization);
    }

    /**
     * @dev Removes the organization from the registry
     * @param  organization  Organization"s Id
     */
    function remove(bytes32 organization) external {
        _removeOrganization(organization);
    }

    /**
     * @dev Get all the registered organizations.
     * @param _cursor Index of the organization from which to start querying.
     * @param _count Number of organizations to go through. Iterates until the end if set to "0" or number higher than the total number of organizations.
     * @return organizationsList Array of organization IDs.
     */
    function getOrganizations(uint256 _cursor, uint256 _count)
        external
        view
        returns (bytes32[] memory organizationsList)
    {
        organizationsList = new bytes32[](getOrganizationsCount(_cursor, _count));
        uint256 index;
        for (uint256 i = _cursor; i < registeredOrganizations.length && (_count == 0 || i < _cursor + _count); i++) {
            if (registeredOrganizations[i] != bytes32(0)) {
                organizationsList[index] = registeredOrganizations[i];
                index++;
            }
        }
    }

    /**
     * @dev Returns a segment name.
     */
    function getSegment() public view returns (string memory) {
        return segment;
    }

    /**
     * @dev Return registeredOrganizations array length.
     * @param _cursor Index of the organization from which to start counting.
     * @param _count Number of organizations to go through. Iterates until the end if set to "0" or number higher than the total number of organizations.
     * @return count Length of the organizations array.
     */
    function getOrganizationsCount(uint256 _cursor, uint256 _count) public view returns (uint256 count) {
        for (uint256 i = _cursor; i < registeredOrganizations.length && (_count == 0 || i < _cursor + _count); i++) {
            if (registeredOrganizations[i] != bytes32(0))
                count++;
        }
    }

    /**
     * @dev Set the list of contract interfaces supported
     */
    function setInterfaces() internal {
        Ownable own;
        DirectoryInterface dir;
        bytes4[3] memory interfaceIds = [
            // ERC165 interface: 0x01ffc9a7
            bytes4(0x01ffc9a7),

            // ownable interface: 0x7f5828d0
            own.owner.selector ^
            own.transferOwnership.selector,

            // directory interface: 0xae54f8e1
            dir.getSegment.selector ^
            dir.getOrganizations.selector ^
            dir.getOrganizationsCount.selector
        ];
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            _registerInterface(interfaceIds[i]);
        }
    }

    /**
     * @dev Add new organization in the directory.
     * Only organizations that conform to OrganizationInterface can be added.
     * ERC165 method of interface checking is used.
     *
     * Emits `OrganizationAdded` on success.
     * @param  organization Organization"s Id
     * @return {
         "organization": "Address of the organization"
     }
     */
    function _addOrganization(bytes32 organization)
        internal
        returns (bytes32)
    {
        require(
            organization != bytes32(0),
            "Directory: Invalid organization Id"
        );
        require(
            organizationsIndex[organization] == 0,
            "Directory: Cannot add organization twice"
        );

        // Get the organization info from the ORG.ID registry
        (
            bool exists,
            ,
            ,
            ,
            ,
            ,
            ,
            address orgOwner,
            address director,
            bool isActive,
            bool isDirectorshipAccepted
        ) = orgId.getOrganization(organization);

        require(
            exists,
            "Directory: Organization not found"
        );

        require(
            orgOwner == msg.sender || director == msg.sender,
            "Directory: Only organization owner or director can add the organization"
        );
        require(
            isActive,
            "Directory: Only enabled organizations can be added"
        );

        if (director != address(0)) {
            require(
                isDirectorshipAccepted,
                "Directory: Only subsidiaries with confirmed director ownership can be added"
            );
        }

        organizationsIndex[organization] = registeredOrganizations.length;
        registeredOrganizations.push(organization);

        emit OrganizationAdded(
            organization,
            organizationsIndex[organization]
        );

        return organization;
    }

    /**
     * @dev Allows a owner to remove an organization
     * from the directory. Does not destroy the organization contract.
     * Emits `OrganizationRemoved` on success.
     * @param  organization  Organization"s address
     */
    function _removeOrganization(bytes32 organization)
        internal
        registeredOrganization(organization)
    {
        // Get the organization info from the ORG.ID registry
        (
            bool exists,
            ,
            ,
            ,
            ,
            ,
            ,
            address orgOwner,
            address director,
            ,
        ) = orgId.getOrganization(organization);

        require(
            exists,
            "Directory: Organization not found"
        );

        require(
            orgOwner == msg.sender || director == msg.sender,
            "Directory: Only organization owner or director can remove the organization"
        );

        uint256 index = organizationsIndex[organization];
        delete registeredOrganizations[index];
        delete organizationsIndex[organization];

        emit OrganizationRemoved(organization);
    }
}
