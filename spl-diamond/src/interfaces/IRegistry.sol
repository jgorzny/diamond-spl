// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IRegistry
/// @notice Interface for the Registry (R) contract which tracks valid feature metadata
/// contracts and the SPL factory address.
interface IRegistry {
    /// @notice Returns true if the given metadata contract address is a valid feature cut
    function validCuts(address _cut) external view returns (bool);

    /// @notice Returns the address of the SPL factory contract
    function spl() external view returns (address);
}
