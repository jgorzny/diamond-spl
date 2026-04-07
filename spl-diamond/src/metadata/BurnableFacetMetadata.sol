// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {BurnableFacet} from "../facets/BurnableFacet.sol";

/// @title BurnableFacetMetadata
/// @notice Metadata contract for the optional Burnable feature.
contract BurnableFacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = BurnableFacet.burn.selector;
        selectors[1] = BurnableFacet.burnFrom.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
