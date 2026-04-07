// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {CrossChainFacet} from "../facets/CrossChainFacet.sol";

/// @title CrossChainFacetMetadata
/// @notice Metadata contract for the optional CrossChain feature.
/// If selected, at most one of SuperchainERC20 or OFT may also be selected (xor).
contract CrossChainFacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = CrossChainFacet.setTrustedRemote.selector;
        selectors[1] = CrossChainFacet.getTrustedRemote.selector;
        selectors[2] = CrossChainFacet.isTrustedRemote.selector;
        selectors[3] = CrossChainFacet.setPaused.selector;
        selectors[4] = CrossChainFacet.crossChainPaused.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
