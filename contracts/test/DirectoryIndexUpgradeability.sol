pragma solidity >=0.5.16;

import "../DirectoryIndex.sol";

/**
 * @title DirectoryIndexUpgradeability
 * @dev A contract for testing DirectoryIndex upgradeability behaviour
 */
contract DirectoryIndexUpgradeability is DirectoryIndex {
    uint256 public test;

    function newFunction() external view returns (uint256) {
        return test;
    }

    function setupNewStorage(uint256 value) external onlyOwner {
        test = value;
    }
}
