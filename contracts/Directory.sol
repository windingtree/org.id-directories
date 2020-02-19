pragma solidity >=0.5.16;

import "openzeppelin-solidity/contracts/introspection/ERC165.sol";
import "openzeppelin-solidity/contracts/introspection/ERC165Checker.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@windingtree/org.id/contracts/OrgIdInterface.sol";
import "./DirectoryInterface.sol";

/**
 * @title Directory
 * @dev A Directory that can handle a list of organizations sharing a 
 * common segment such as hotels, airlines etc.
 */
contract Directory is Ownable, DirectoryInterface, ERC165, Initializable {

    using SafeMath for uint256;

    // An instance of the ORG.ID smart contract
    OrgIdInterface public orgId;
    
    // Segment name, i. e. hotel, airline
    string internal segment;

    // Array of addresses of `Organization` contracts
    bytes32[] organizations;

    // Mapping of organizations position in the general organization index
    mapping(bytes32 => uint256) organizationsIndex;

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
            ERC165Checker._supportsInterface(_orgId, 0x36b78f0f),
            "Directory: ORG.ID instance has to support ORG.ID interface"
        );
        
        setInterfaces();
        _transferOwnership(__owner);
        orgId = OrgIdInterface(_orgId);
        segment = _segment;
        organizationsIndex[bytes32(0)] = organizations.length;
        organizations.push(bytes32(0));
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
     * @dev Returns the segment name
     */
    function getSegment() external view returns (string memory) {
        return segment;
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
     * @dev Returns registered organizations array
     * @return {
         "organizationsList": "Array of organization Ids"
     }
     */
    function getOrganizations() 
        external 
        view 
        returns (bytes32[] memory organizationsList) 
    {
        organizationsList = new bytes32[](_getOrganizationsCount());
        uint256 index;

        for (uint256 i = 0; i < organizations.length; i++) {

            if (organizations[i] != bytes32(0)) {

                organizationsList[index] = organizations[i];
                index = index.add(1);
            }
        }
    }

    /**
     * @dev Set the list of contract interfaces supported
     */
    function setInterfaces() public {
        Ownable own;
        DirectoryInterface dir;
        bytes4[3] memory interfaceIds = [
            // ERC165 interface: 0x01ffc9a7
            bytes4(0x01ffc9a7),

            // ownable interface: 0x7f5828d0
            own.owner.selector ^ 
            own.transferOwnership.selector, 

            // directory interface: 0xcc915ab7
            dir.setSegment.selector ^ 
            dir.getSegment.selector ^
            dir.add.selector ^ 
            dir.remove.selector ^
            dir.getOrganizations.selector
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
        ( , , , , address orgOwner, address director, bool orgState, bool directorConfirmed) = orgId.getOrganization(organization);
        
        require(
            orgOwner == msg.sender || director == msg.sender,
            "Directory: Only organization owner or director can add the organization"
        );
        require(
            orgState,
            "Directory: Only enabled organizations can be added"
        );
        
        if (director != address(0)) {
            require(
                directorConfirmed,
                "Directory: Only subsidiaries with confirmed director ownership can be added"
            );
        }
        
        organizationsIndex[organization] = organizations.length;
        organizations.push(organization);

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
        ( , , , , address orgOwner, address director, , ) = orgId.getOrganization(organization);

        require(
            orgOwner == msg.sender || director == msg.sender,
            "Directory: Only organization owner or director can remove the organization"
        );

        uint256 index = organizationsIndex[organization];
        delete organizations[index];
        delete organizationsIndex[organization];
        
        emit OrganizationRemoved(organization);
    }

    /**
     * @dev Returns organizations array length
     * @return {
         "count": "Length of the organizations array"
     }
     */
    function _getOrganizationsCount() internal view returns (uint256 count) {
        
        for (uint256 i = 0; i < organizations.length; i++) {

            if (organizations[i] != bytes32(0)) {
                
                count = count.add(1);
            }
        }
    }
}
