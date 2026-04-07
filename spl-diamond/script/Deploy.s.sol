// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

// Infrastructure facets
import {DiamondCutFacet}   from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet}    from "../src/facets/OwnershipFacet.sol";

// Feature facets
import {ERC20Facet}           from "../src/facets/ERC20Facet.sol";
import {BurnableFacet}        from "../src/facets/BurnableFacet.sol";
import {ExtraFacet}           from "../src/facets/ExtraFacet.sol";
import {MetadataFacet}        from "../src/facets/MetadataFacet.sol";
import {PermitFacet}          from "../src/facets/PermitFacet.sol";
import {CrossChainFacet}      from "../src/facets/CrossChainFacet.sol";
import {SuperchainERC20Facet} from "../src/facets/SuperchainERC20Facet.sol";
import {OFTFacet}             from "../src/facets/OFTFacet.sol";

// Metadata contracts
import {DiamondCutFacetMetadata}      from "../src/metadata/DiamondCutFacetMetadata.sol";
import {DiamondLoupeFacetMetadata}    from "../src/metadata/DiamondLoupeFacetMetadata.sol";
import {OwnershipFacetMetadata}       from "../src/metadata/OwnershipFacetMetadata.sol";
import {ERC20FacetMetadata}           from "../src/metadata/ERC20FacetMetadata.sol";
import {BurnableFacetMetadata}        from "../src/metadata/BurnableFacetMetadata.sol";
import {ExtraFacetMetadata}           from "../src/metadata/ExtraFacetMetadata.sol";
import {MetadataFacetMetadata}        from "../src/metadata/MetadataFacetMetadata.sol";
import {PermitFacetMetadata}          from "../src/metadata/PermitFacetMetadata.sol";
import {CrossChainFacetMetadata}      from "../src/metadata/CrossChainFacetMetadata.sol";
import {SuperchainERC20FacetMetadata} from "../src/metadata/SuperchainERC20FacetMetadata.sol";
import {OFTFacetMetadata}             from "../src/metadata/OFTFacetMetadata.sol";

// SPL core
import {Registry}    from "../src/Registry.sol";
import {DiamondInit} from "../src/DiamondInit.sol";
import {SPL}         from "../src/SPL.sol";

/// @title Deploy
/// @notice Full deployment of the SPL product line following the methodology
/// described in Section III of the paper. Logs all deployed addresses.
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // -- Step 1: Deploy facet implementation contracts --------------------
        DiamondCutFacet   diamondCutFacet   = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet    ownershipFacet    = new OwnershipFacet();
        ERC20Facet           erc20Facet           = new ERC20Facet();
        BurnableFacet        burnableFacet        = new BurnableFacet();
        ExtraFacet           extraFacet           = new ExtraFacet();
        MetadataFacet        metadataFacet        = new MetadataFacet();
        PermitFacet          permitFacet          = new PermitFacet();
        CrossChainFacet      crossChainFacet      = new CrossChainFacet();
        SuperchainERC20Facet superchainERC20Facet = new SuperchainERC20Facet();
        OFTFacet             oftFacet             = new OFTFacet();

        console2.log("=== Facet Implementations ===");
        console2.log("DiamondCutFacet:      ", address(diamondCutFacet));
        console2.log("DiamondLoupeFacet:    ", address(diamondLoupeFacet));
        console2.log("OwnershipFacet:       ", address(ownershipFacet));
        console2.log("ERC20Facet:           ", address(erc20Facet));
        console2.log("BurnableFacet:        ", address(burnableFacet));
        console2.log("ExtraFacet:           ", address(extraFacet));
        console2.log("MetadataFacet:        ", address(metadataFacet));
        console2.log("PermitFacet:          ", address(permitFacet));
        console2.log("CrossChainFacet:      ", address(crossChainFacet));
        console2.log("SuperchainERC20Facet: ", address(superchainERC20Facet));
        console2.log("OFTFacet:             ", address(oftFacet));

        // -- Step 2: Deploy metadata contracts --------------------------------
        DiamondCutFacetMetadata      meta_DiamondCut      = new DiamondCutFacetMetadata(address(diamondCutFacet));
        DiamondLoupeFacetMetadata    meta_DiamondLoupe    = new DiamondLoupeFacetMetadata(address(diamondLoupeFacet));
        OwnershipFacetMetadata       meta_Ownership       = new OwnershipFacetMetadata(address(ownershipFacet));
        ERC20FacetMetadata           meta_ERC20           = new ERC20FacetMetadata(address(erc20Facet));
        BurnableFacetMetadata        meta_Burnable        = new BurnableFacetMetadata(address(burnableFacet));
        ExtraFacetMetadata           meta_Extra           = new ExtraFacetMetadata(address(extraFacet));
        MetadataFacetMetadata        meta_Metadata        = new MetadataFacetMetadata(address(metadataFacet));
        PermitFacetMetadata          meta_Permit          = new PermitFacetMetadata(address(permitFacet));
        CrossChainFacetMetadata      meta_CrossChain      = new CrossChainFacetMetadata(address(crossChainFacet));
        SuperchainERC20FacetMetadata meta_SuperchainERC20 = new SuperchainERC20FacetMetadata(address(superchainERC20Facet));
        OFTFacetMetadata             meta_OFT             = new OFTFacetMetadata(address(oftFacet));

        console2.log("\n=== Metadata Contracts ===");
        console2.log("meta_DiamondCut:      ", address(meta_DiamondCut));
        console2.log("meta_DiamondLoupe:    ", address(meta_DiamondLoupe));
        console2.log("meta_Ownership:       ", address(meta_Ownership));
        console2.log("meta_ERC20:           ", address(meta_ERC20));
        console2.log("meta_Burnable:        ", address(meta_Burnable));
        console2.log("meta_Extra:           ", address(meta_Extra));
        console2.log("meta_Metadata:        ", address(meta_Metadata));
        console2.log("meta_Permit:          ", address(meta_Permit));
        console2.log("meta_CrossChain:      ", address(meta_CrossChain));
        console2.log("meta_SuperchainERC20: ", address(meta_SuperchainERC20));
        console2.log("meta_OFT:             ", address(meta_OFT));

        // -- Step 3: Deploy Registry with all valid metadata addresses --------
        address[] memory validCuts = new address[](11);
        validCuts[0]  = address(meta_DiamondCut);
        validCuts[1]  = address(meta_DiamondLoupe);
        validCuts[2]  = address(meta_Ownership);
        validCuts[3]  = address(meta_ERC20);
        validCuts[4]  = address(meta_Burnable);
        validCuts[5]  = address(meta_Extra);
        validCuts[6]  = address(meta_Metadata);
        validCuts[7]  = address(meta_Permit);
        validCuts[8]  = address(meta_CrossChain);
        validCuts[9]  = address(meta_SuperchainERC20);
        validCuts[10] = address(meta_OFT);

        Registry registry = new Registry(validCuts);
        DiamondInit diamondInit = new DiamondInit();

        console2.log("\n=== Core SPL Contracts ===");
        console2.log("Registry:    ", address(registry));
        console2.log("DiamondInit: ", address(diamondInit));

        // -- Step 4 & 5: Deploy SPL factory -----------------------------------
        SPL.FeatureAddresses memory fa = SPL.FeatureAddresses({
            diamondCut:      address(meta_DiamondCut),
            diamondLoupe:    address(meta_DiamondLoupe),
            ownership:       address(meta_Ownership),
            erc20:           address(meta_ERC20),
            burnable:        address(meta_Burnable),
            extra:           address(meta_Extra),
            metadata:        address(meta_Metadata),
            permit:          address(meta_Permit),
            crossChain:      address(meta_CrossChain),
            superchainERC20: address(meta_SuperchainERC20),
            oft:             address(meta_OFT),
            init:            address(diamondInit)
        });

        SPL spl = new SPL(fa, address(registry));
        console2.log("SPL:         ", address(spl));

        // -- Step 6: Register SPL factory in Registry -------------------------
        registry.setFactory(address(spl));
        console2.log("\nFactory registered in Registry.");

        vm.stopBroadcast();

        // -- Example: create a minimal product (ERC20 only) -------------------
        console2.log("\n=== Example Product (ERC20 + Metadata) ===");
        // Note: would call spl.createProduct(...) here in a broadcast
    }
}
