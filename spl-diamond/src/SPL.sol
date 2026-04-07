// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Product} from "./Product.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";

/// @title SPL
/// @notice The Software Product Line factory contract (Section III of the paper).
///
/// Anyone can call createProduct() with a valid feature configuration to instantiate
/// a new Product diamond entirely on-chain - no Solidity compiler required.
///
/// Feature model (from Figure 2 of the paper, implemented as propositional constraints):
///
///   Features:
///     F0  ERC20           - mandatory (always required)
///     F1  Burnable        - optional
///     F2  Extra           - optional group parent
///     F3  Metadata        - optional (sub-feature of Extra; or-group)
///     F4  Permit          - optional (sub-feature of Extra; or-group)
///     F5  CrossChain      - optional group parent
///     F6  SuperchainERC20 - optional (sub-feature of CrossChain; xor-group)
///     F7  OFT             - optional (sub-feature of CrossChain; xor-group)
///
///   Hierarchy constraints:
///     C1  ERC20 is mandatory                        [always required]
///     C2  If Extra: at least one of {Metadata, Permit} (or-group)
///     C3  If CrossChain: at most one of {SuperchainERC20, OFT} (xor-group)
///     C4  Metadata - Extra  (Metadata requires Extra)
///     C5  Permit - Extra  (Permit requires Extra)
///     C6  SuperchainERC20 - CrossChain
///     C7  OFT - CrossChain
///
///   Cross-tree constraint:
///     C8  SuperchainERC20 ==> Burnable
///
/// The isValidProduct function encodes all constraints as require() statements,
/// matching the Python-generated Solidity described in Section III of the paper.
contract SPL {
    // -----------------------------------------------------------------------
    // Feature metadata contract addresses
    // These are set at construction and correspond to the registered cuts in
    // the Registry. The mapping (address => bool) enables O(1) membership checks.
    // -----------------------------------------------------------------------

    address public immutable registry;

    // Infrastructure (always included - not part of the feature model per se,
    // but required for a functional diamond)
    address public immutable meta_DiamondCut;
    address public immutable meta_DiamondLoupe;
    address public immutable meta_Ownership;

    // Feature metadata contracts (F0-F7)
    address public immutable meta_ERC20;           // F0 - mandatory
    address public immutable meta_Burnable;        // F1 - optional
    address public immutable meta_Extra;           // F2 - optional group parent (no facet, logic-only)
    address public immutable meta_Metadata;        // F3 - optional, sub of Extra
    address public immutable meta_Permit;          // F4 - optional, sub of Extra
    address public immutable meta_CrossChain;      // F5 - optional group parent
    address public immutable meta_SuperchainERC20; // F6 - optional, sub of CrossChain
    address public immutable meta_OFT;             // F7 - optional, sub of CrossChain

    // DiamondInit used by all products
    address public immutable diamondInit;

    // Quick membership lookup for the set of known metadata addresses
    mapping(address => bool) private _isKnownMeta;

    event ProductCreated(address indexed product, address indexed owner, address[] features);

    struct FeatureAddresses {
        address diamondCut;
        address diamondLoupe;
        address ownership;
        address erc20;
        address burnable;
        address extra;
        address metadata;
        address permit;
        address crossChain;
        address superchainERC20;
        address oft;
        address init;
    }

    constructor(FeatureAddresses memory fa, address _registry) {
        registry = _registry;

        meta_DiamondCut      = fa.diamondCut;
        meta_DiamondLoupe    = fa.diamondLoupe;
        meta_Ownership       = fa.ownership;
        meta_ERC20           = fa.erc20;
        meta_Burnable        = fa.burnable;
        meta_Extra           = fa.extra;
        meta_Metadata        = fa.metadata;
        meta_Permit          = fa.permit;
        meta_CrossChain      = fa.crossChain;
        meta_SuperchainERC20 = fa.superchainERC20;
        meta_OFT             = fa.oft;
        diamondInit          = fa.init;

        // Populate membership map
        _isKnownMeta[fa.diamondCut]      = true;
        _isKnownMeta[fa.diamondLoupe]    = true;
        _isKnownMeta[fa.ownership]       = true;
        _isKnownMeta[fa.erc20]           = true;
        _isKnownMeta[fa.burnable]        = true;
        _isKnownMeta[fa.extra]           = true;
        _isKnownMeta[fa.metadata]        = true;
        _isKnownMeta[fa.permit]          = true;
        _isKnownMeta[fa.crossChain]      = true;
        _isKnownMeta[fa.superchainERC20] = true;
        _isKnownMeta[fa.oft]             = true;
    }

    // -----------------------------------------------------------------------
    // Public entry point
    // -----------------------------------------------------------------------

    /// @notice Create a new on-chain Product with the given feature configuration.
    /// @param _features Ordered list of metadata contract addresses representing
    ///                  the desired product features. Must be a valid configuration
    ///                  per the feature model constraints.
    /// @param _owner    Owner of the new Product diamond
    /// @return product  Address of the deployed Product contract
    function createProduct(address[] calldata _features, address _owner)
        external
        returns (address product)
    {
        // Validate the feature configuration against the feature model
        isValidProduct(_features);

        Product.DiamondArgs memory args = Product.DiamondArgs({
            owner: _owner,
            init: diamondInit,
            initCalldata: abi.encodeWithSignature("init()")
        });

        Product p = new Product(registry, _features, args);
        emit ProductCreated(address(p), _owner, _features);
        return address(p);
    }

    // -----------------------------------------------------------------------
    // Feature model validation (Sec. III - isValidProduct)
    //
    // Generated from the UVL feature model by a Python script (per the paper).
    // Each require() encodes one propositional constraint from the feature model.
    // Reverts if the configuration is invalid.
    // -----------------------------------------------------------------------

    /// @notice Validate that a feature set satisfies the feature model constraints.
    ///         Reverts with a descriptive reason if any constraint is violated.
    /// @param _features List of metadata addresses representing selected features
    function isValidProduct(address[] calldata _features) public view {
        // Generated by uvl2sol_require.py
        // Namespace : TokenProductLine
        // Root      : Token
        // Features  : DiamondCut, DiamondLoupe, Ownership (infra), ERC20, Burnable, Extra, Metadata, Permit, CrossChain, SuperchainERC20, OFT

        // -- Feature presence flags -------------------------------------------
        bool hasDiamondCut = false;
        bool hasDiamondLoupe = false;
        bool hasOwnership = false;
        bool hasERC20 = false;
        bool hasBurnable = false;
        bool hasExtra = false;
        bool hasMetadata = false;
        bool hasPermit = false;
        bool hasCrossChain = false;
        bool hasSuperchainERC20 = false;
        bool hasOFT = false;

        // -- Scan _features and set flags -------------------------------------
        for (uint256 i = 0; i < _features.length; i++) {
            address f = _features[i];
            require(_isKnownMeta[f], "SPL: unknown feature address");

            if (f == meta_DiamondCut) hasDiamondCut = true;
            else if (f == meta_DiamondLoupe) hasDiamondLoupe = true;
            else if (f == meta_Ownership) hasOwnership = true;
            else if (f == meta_ERC20) hasERC20 = true;
            else if (f == meta_Burnable) hasBurnable = true;
            else if (f == meta_Extra) hasExtra = true;
            else if (f == meta_Metadata) hasMetadata = true;
            else if (f == meta_Permit) hasPermit = true;
            else if (f == meta_CrossChain) hasCrossChain = true;
            else if (f == meta_SuperchainERC20) hasSuperchainERC20 = true;
            else if (f == meta_OFT) hasOFT = true;
        }

        // -- Infrastructure requirements --------------------------------------
        require(hasDiamondCut, "SPL: DiamondCut facet is required");
        require(hasDiamondLoupe, "SPL: DiamondLoupe facet is required");
        require(hasOwnership, "SPL: Ownership facet is required");

        // -- Hierarchy constraints --------------------------------------------
        require(hasERC20, "SPL: ERC20 is mandatory");
        require(!hasMetadata || hasExtra, "SPL: Metadata requires Extra");
        require(!hasPermit || hasExtra, "SPL: Permit requires Extra");
        require(!hasExtra || (hasMetadata || hasPermit), "SPL: Extra requires at least one of {Metadata, Permit}");
        require(!hasSuperchainERC20 || hasCrossChain, "SPL: SuperchainERC20 requires CrossChain");
        require(!hasOFT || hasCrossChain, "SPL: OFT requires CrossChain");
        require(!(hasSuperchainERC20 && hasOFT), "SPL: SuperchainERC20 and OFT are mutually exclusive");

        // -- Cross-tree constraints -------------------------------------------
        require((!hasSuperchainERC20 || hasBurnable), "SPL: SuperchainERC20 implies Burnable");
        
    }
}
