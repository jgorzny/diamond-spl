// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {PermitFacet} from "../facets/PermitFacet.sol";

/// @title PermitFacetMetadata
/// @notice Metadata contract for the optional Permit feature (sub-feature of Extra).
contract PermitFacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = PermitFacet.permit.selector;
        selectors[1] = PermitFacet.nonces.selector;
        selectors[2] = PermitFacet.DOMAIN_SEPARATOR.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
