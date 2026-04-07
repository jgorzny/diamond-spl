// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFacetMetadata} from "../interfaces/IFacetMetadata.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {ERC20Facet} from "../facets/ERC20Facet.sol";

/// @title ERC20FacetMetadata
/// @notice Metadata contract for the ERC20 feature.
/// Registered in the Registry as a valid cut. The SPL calls getFacetCut()
/// to retrieve the FacetCut struct needed to wire this feature into a Product diamond.
contract ERC20FacetMetadata is IFacetMetadata {
    address public immutable facet;

    constructor(address _facet) {
        facet = _facet;
    }

    function getFacetCut() external view override returns (IDiamondCut.FacetCut memory) {
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = ERC20Facet.totalSupply.selector;
        selectors[1] = ERC20Facet.balanceOf.selector;
        selectors[2] = ERC20Facet.transfer.selector;
        selectors[3] = ERC20Facet.transferFrom.selector;
        selectors[4] = ERC20Facet.approve.selector;
        selectors[5] = ERC20Facet.allowance.selector;
        selectors[6] = ERC20Facet.mint.selector;

        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
