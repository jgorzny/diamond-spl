// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CrossChainFacet
/// @notice Optional feature: base cross-chain functionality.
/// Per the feature model, if CrossChain is selected at most one of
/// SuperchainERC20 or OFT may also be chosen (xor group).
/// This facet holds shared cross-chain configuration.
library LibCrossChain {
    bytes32 constant CROSSCHAIN_STORAGE_POSITION = keccak256("diamond.storage.crosschain");

    struct Storage {
        mapping(uint16 => bytes) trustedRemotes; // chainId => remote address
        bool paused;
    }

    function layout() internal pure returns (Storage storage s) {
        bytes32 position = CROSSCHAIN_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}

contract CrossChainFacet {
    event TrustedRemoteSet(uint16 indexed chainId, bytes remote);
    event CrossChainPauseToggled(bool paused);

    function setTrustedRemote(uint16 chainId, bytes calldata remote) external {
        // In production: enforce owner
        LibCrossChain.layout().trustedRemotes[chainId] = remote;
        emit TrustedRemoteSet(chainId, remote);
    }

    function getTrustedRemote(uint16 chainId) external view returns (bytes memory) {
        return LibCrossChain.layout().trustedRemotes[chainId];
    }

    function isTrustedRemote(uint16 chainId, bytes calldata remote) external view returns (bool) {
        return keccak256(LibCrossChain.layout().trustedRemotes[chainId]) == keccak256(remote);
    }

    function setPaused(bool _paused) external {
        LibCrossChain.layout().paused = _paused;
        emit CrossChainPauseToggled(_paused);
    }

    function crossChainPaused() external view returns (bool) {
        return LibCrossChain.layout().paused;
    }
}
