// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibPermit
/// @notice Diamond storage for ERC20-Permit (EIP-2612) nonces.
/// Isolated storage so the Permit facet is fully optional.
library LibPermit {
    bytes32 constant PERMIT_STORAGE_POSITION = keccak256("diamond.storage.erc20.permit");

    struct Storage {
        mapping(address => uint256) nonces;
    }

    function layout() internal pure returns (Storage storage s) {
        bytes32 position = PERMIT_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
