// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {SuperchainERC20Facet} from "../facets/SuperchainERC20Facet.sol";

/// @title SuperchainERC20FacetMetadata
/// @notice Metadata contract for the optional SuperchainERC20 feature (xor sub-feature of CrossChain).
/// Constraint: SuperchainERC20 => Burnable (enforced by isValidProduct in SPL).
contract SuperchainERC20FacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = SuperchainERC20Facet.superchainMint.selector;
        selectors[1] = SuperchainERC20Facet.superchainBurn.selector;
        selectors[2] = SuperchainERC20Facet.setSuperchainBridge.selector;
        selectors[3] = SuperchainERC20Facet.superchainBridge.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
