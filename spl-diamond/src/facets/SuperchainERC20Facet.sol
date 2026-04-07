// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibERC20} from "../libraries/LibERC20.sol";

/// @title SuperchainERC20Facet
/// @notice Optional feature (xor sub-feature of CrossChain): Superchain cross-chain token bridge.
/// Requires the Burnable feature (constraint: SuperchainERC20 => Burnable).
/// Uses ERC20 storage for minting/burning operations.
///
/// NOTE: In a production system this would integrate with the Superchain bridge
/// contracts. This prototype shows the pattern and storage isolation.
contract SuperchainERC20Facet {
    /// @notice Address of the Superchain bridge (set at initialization)
    bytes32 constant SUPERCHAIN_STORAGE_POSITION = keccak256("diamond.storage.superchain");

    struct SuperchainStorage {
        address bridge;
    }

    function _superchainStorage() internal pure returns (SuperchainStorage storage s) {
        bytes32 position = SUPERCHAIN_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    event SuperchainMint(address indexed to, uint256 amount, uint32 sourceChainId);
    event SuperchainBurn(address indexed from, uint256 amount, uint32 destChainId);

    /// @notice Called by the Superchain bridge to mint tokens on this chain
    function superchainMint(address to, uint256 amount, uint32 sourceChainId) external {
        require(msg.sender == _superchainStorage().bridge, "SuperchainERC20: only bridge");
        LibERC20._mint(to, amount);
        emit SuperchainMint(to, amount, sourceChainId);
    }

    /// @notice Burns tokens to initiate a cross-chain transfer via the Superchain bridge.
    /// Relies on BurnableFacet being present (enforced by isValidProduct constraint).
    function superchainBurn(address from, uint256 amount, uint32 destChainId) external {
        require(msg.sender == _superchainStorage().bridge, "SuperchainERC20: only bridge");
        LibERC20._burn(from, amount);
        emit SuperchainBurn(from, amount, destChainId);
    }

    function setSuperchainBridge(address bridge) external {
        _superchainStorage().bridge = bridge;
    }

    function superchainBridge() external view returns (address) {
        return _superchainStorage().bridge;
    }
}
