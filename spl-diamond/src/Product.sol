// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {IFacetMetadata} from "./interfaces/IFacetMetadata.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";

/// @title Product
/// @notice A diamond-pattern smart contract product instantiated by the SPL factory.
///
/// This is the core modification to ERC-2535 described in Section III of the paper.
/// Key differences from a standard diamond:
///
///   1. The constructor accepts an array of metadata contract addresses (_diamondCuts)
///      instead of a pre-built FacetCut[] array. Each metadata address must be
///      registered in the Registry as a validCut.
///
///   2. The constructor enforces that msg.sender is the SPL factory (recorded in
///      the Registry) - preventing Products from being deployed outside the SPL.
///
///   3. Each metadata contract's getFacetCut() is called to retrieve the FacetCut
///      and add the feature, keeping the feature-to-facet mapping explicit.
///
/// This enables anyone to instantiate valid products entirely on-chain by calling
/// SPL.createProduct() - no Solidity compiler required after initial setup.
contract Product {
    /// @notice The Registry address is baked in at construction time.
    /// In a generated product line this would be a constant; here we use
    /// an immutable to allow the same bytecode to be tested with different registries.
    address public immutable registry;

    struct DiamondArgs {
        address owner;
        address init; // address of DiamondInit (or address(0) to skip)
        bytes initCalldata; // calldata for the init delegatecall
    }

    /// @param _registry       Address of the Registry contract
    /// @param _diamondCuts    Ordered list of metadata contract addresses (one per feature)
    /// @param _args           Owner, optional init contract, and init calldata
    constructor(address _registry, address[] memory _diamondCuts, DiamondArgs memory _args) payable {
        registry = _registry;

        // Paper Sec. III step 4: "ensure that the contract was not created by any
        // other address" than the SPL factory.
        require(msg.sender == IRegistry(_registry).spl(), "Product: only SPL factory may deploy products");

        LibDiamond.setContractOwner(_args.owner);

        // Paper Sec. III step 4: validate each metadata address against the registry,
        // then call getFacetCut() and wire the facet into the diamond.
        for (uint256 i = 0; i < _diamondCuts.length; i++) {
            require(
                IRegistry(_registry).validCuts(_diamondCuts[i]), "Product: metadata address not registered in Registry"
            );

            IDiamondCut.FacetCut memory cut = IFacetMetadata(_diamondCuts[i]).getFacetCut();
            IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
            cuts[0] = cut;
            // address(0) / "" for init here - we run the single init at the end
            LibDiamond.diamondCut(cuts, address(0), "");
        }

        // Run optional initialization (e.g., DiamondInit to set ERC-165 interfaces)
        if (_args.init != address(0)) {
            LibDiamond.initializeDiamondCut(_args.init, _args.initCalldata);
        }
    }

    /// @notice Fallback routes calls to the appropriate facet using delegatecall,
    /// exactly as in the ERC-2535 reference implementation.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Product: function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
