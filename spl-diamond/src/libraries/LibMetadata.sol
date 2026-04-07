// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibMetadata
/// @notice Diamond storage for ERC20 metadata (name, symbol, decimals).
/// Isolated to its own storage slot so the Metadata facet can be optional.
library LibMetadata {
    bytes32 constant METADATA_STORAGE_POSITION = keccak256("diamond.storage.erc20.metadata");

    struct Storage {
        string name;
        string symbol;
        uint8 decimals;
    }

    function layout() internal pure returns (Storage storage s) {
        bytes32 position = METADATA_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
