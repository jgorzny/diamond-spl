// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Registry
/// @notice The Registry contract (R in the paper) tracks which metadata contracts
/// are valid feature cuts for this product line, and holds the address of the
/// SPL factory. The diamond Product constructor queries this contract to validate
/// each facet before adding it.
///
/// Deployment order (per Section III of the paper):
///   1. Deploy all facet implementation contracts
///   2. Deploy all metadata contracts (one per feature)
///   3. Deploy Registry with the list of valid metadata contract addresses
///   4. Deploy SPL factory and call setFactory() on the Registry
contract Registry {
    address public owner;

    /// @notice The SPL factory contract address - only Products created by this
    /// address are valid. Set after SPL is deployed via setFactory().
    address public spl;

    /// @notice Returns true if the given metadata contract address is a registered
    /// valid feature cut for this product line.
    mapping(address => bool) public validCuts;

    event CutRegistered(address indexed cut);
    event CutRevoked(address indexed cut);
    event FactorySet(address indexed spl);

    constructor(address[] memory _validCuts) {
        owner = msg.sender;
        for (uint256 i = 0; i < _validCuts.length; i++) {
            validCuts[_validCuts[i]] = true;
            emit CutRegistered(_validCuts[i]);
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Registry: not owner");
        _;
    }

    /// @notice Set the SPL factory address. Called after SPL is deployed.
    /// @param _spl Address of the deployed SPL factory contract
    function setFactory(address _spl) external onlyOwner {
        require(_spl != address(0), "Registry: zero address");
        spl = _spl;
        emit FactorySet(_spl);
    }

    /// @notice Register an additional metadata contract as a valid feature cut
    function addValidCut(address _cut) external onlyOwner {
        require(_cut != address(0), "Registry: zero address");
        validCuts[_cut] = true;
        emit CutRegistered(_cut);
    }

    /// @notice Revoke a previously registered metadata contract
    function revokeValidCut(address _cut) external onlyOwner {
        validCuts[_cut] = false;
        emit CutRevoked(_cut);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Registry: zero address");
        owner = _newOwner;
    }
}
