pragma solidity ^0.5.6;

import "./SegmentDirectoryEvents.sol";

contract AbstractWTAirlineIndex is SegmentDirectoryEvents {
    function registerAirline(string calldata dataUri) external returns (address);
    function deleteAirline(address airline) external;
    function callAirline(address airline, bytes calldata data) external;
    function transferAirline(address airline, address payable newManager) external;
    function getAirlinesLength() public view returns (uint);
    function getAirlines() public view returns (address[] memory);
    function getAirlinesByManager(address manager) public view returns (address[] memory);
    function airlinesIndex(address hotel) public view returns (uint);
    function airlines(uint index) public view returns (address);
}
