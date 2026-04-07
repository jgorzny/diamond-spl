// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {MetadataFacet} from "../facets/MetadataFacet.sol";

/// @title MetadataFacetMetadata
/// @notice Metadata contract for the optional Metadata feature (sub-feature of Extra).
contract MetadataFacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = MetadataFacet.name.selector;
        selectors[1] = MetadataFacet.symbol.selector;
        selectors[2] = MetadataFacet.decimals.selector;
        selectors[3] = MetadataFacet.initMetadata.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
