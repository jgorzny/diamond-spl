// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ExtraFacet
/// @notice Optional group parent feature for {Metadata, Permit}.
/// Per the feature model (Figure 2 of the paper): if Extra is selected,
/// at least one of its sub-features {Metadata, Permit} must also be selected (or-group).
/// This facet holds the group-level state and a marker function so it can be a
/// real on-chain facet per the one-feature-one-facet principle.
library LibExtra {
    bytes32 constant EXTRA_STORAGE_POSITION = keccak256("diamond.storage.extra");

    struct Storage {
        bool initialized;
    }

    function layout() internal pure returns (Storage storage s) {
        bytes32 position = EXTRA_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}

contract ExtraFacet {
    /// @notice Returns true, indicating the Extra feature group is active.
    /// Also serves as the selector that represents this feature in the diamond.
    function extraEnabled() external pure returns (bool) {
        return true;
    }
}
