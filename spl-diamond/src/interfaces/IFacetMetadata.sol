// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondCut} from "./IDiamondCut.sol";

/// @title IFacetMetadata
/// @notice Interface that every metadata contract must implement.
/// Each feature in the SPL has a corresponding metadata contract that
/// describes how to add that feature's facet to a diamond Product.
interface IFacetMetadata {
    /// @notice Returns the FacetCut needed to add this feature's facet to a diamond
    /// @return The FacetCut struct with action=Add, the facet address, and its function selectors
    function getFacetCut() external view returns (IDiamondCut.FacetCut memory);
}
