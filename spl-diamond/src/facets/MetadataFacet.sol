// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibMetadata} from "../libraries/LibMetadata.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/// @title MetadataFacet
/// @notice Optional feature (sub-feature of Extra): ERC20 token metadata — name, symbol, decimals.
/// Storage isolated via LibMetadata so this facet can be added or omitted independently.
contract MetadataFacet {
    function name() external view returns (string memory) {
        return LibMetadata.layout().name;
    }

    function symbol() external view returns (string memory) {
        return LibMetadata.layout().symbol;
    }

    function decimals() external view returns (uint8) {
        return LibMetadata.layout().decimals;
    }

    /// @notice Initialize metadata - called by DiamondInit during product construction
    function initMetadata(string calldata _name, string calldata _symbol, uint8 _decimals) external {
        LibDiamond.enforceIsContractOwner();
        LibMetadata.Storage storage s = LibMetadata.layout();
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
    }
}
