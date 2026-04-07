// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {DiamondCutFacet} from "../facets/DiamondCutFacet.sol";

/// @title DiamondCutFacetMetadata
/// @notice Metadata contract for the DiamondCut infrastructure facet.
/// Always included in Product diamonds to allow post-deployment upgrades.
contract DiamondCutFacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = DiamondCutFacet.diamondCut.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
