// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {OFTFacet} from "../facets/OFTFacet.sol";

/// @title OFTFacetMetadata
/// @notice Metadata contract for the optional OFT feature (xor sub-feature of CrossChain).
/// Mutually exclusive with SuperchainERC20Facet (xor enforced by isValidProduct in SPL).
contract OFTFacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = OFTFacet.estimateSendFee.selector;
        selectors[1] = OFTFacet.sendFrom.selector;
        selectors[2] = OFTFacet.lzReceive.selector;
        selectors[3] = OFTFacet.setLzEndpoint.selector;
        selectors[4] = OFTFacet.lzEndpoint.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
