// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

// -- SPL infrastructure -------------------------------------------------------
import {DiamondCutFacet}   from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet}    from "../src/facets/OwnershipFacet.sol";
import {ERC20Facet}           from "../src/facets/ERC20Facet.sol";
import {BurnableFacet}        from "../src/facets/BurnableFacet.sol";
import {ExtraFacet}           from "../src/facets/ExtraFacet.sol";

import {DiamondCutFacetMetadata}   from "../src/metadata/DiamondCutFacetMetadata.sol";
import {DiamondLoupeFacetMetadata} from "../src/metadata/DiamondLoupeFacetMetadata.sol";
import {OwnershipFacetMetadata}    from "../src/metadata/OwnershipFacetMetadata.sol";
import {ERC20FacetMetadata}        from "../src/metadata/ERC20FacetMetadata.sol";
import {BurnableFacetMetadata}     from "../src/metadata/BurnableFacetMetadata.sol";

import {Registry}    from "../src/Registry.sol";
import {DiamondInit} from "../src/DiamondInit.sol";
import {SPL}         from "../src/SPL.sol";

// -- Baseline -----------------------------------------------------------------
import {PlainERC20Burnable} from "../src/PlainERC20Burnable.sol";

/// @title GasComparisonTest
/// @notice Measures and compares the gas cost of calling burn() on:
///   (A) a diamond SPL Product with ERC20 + Burnable facets, and
///   (B) a monolithic PlainERC20Burnable contract.
///
/// Run with:
///   forge test --match-contract GasComparisonTest -vv
///
/// For a full per-function gas table across all tests, run:
///   forge test --gas-report
contract GasComparisonTest is Test {
    // Diamond product address (cast as ERC20Facet / BurnableFacet for calls)
    address diamondProduct;

    // Monolithic baseline
    PlainERC20Burnable plain;

    address owner = makeAddr("owner");
    address user  = makeAddr("user");

    uint256 constant MINT_AMOUNT = 1000e18;
    uint256 constant BURN_AMOUNT = 100e18;

    // -- Setup: deploy both contracts -----------------------------------------

    function setUp() public {
        diamondProduct = _deployDiamondProduct();
        vm.prank(owner);
        ERC20Facet(diamondProduct).mint(user, MINT_AMOUNT);

        vm.prank(owner);
        plain = new PlainERC20Burnable();
        vm.prank(owner);
        plain.mint(user, MINT_AMOUNT);
    }

    /// @dev Broken out to avoid stack-too-deep in setUp.
    function _deployDiamondProduct() internal returns (address product) {
        // Facet implementations
        address cut   = address(new DiamondCutFacet());
        address loupe = address(new DiamondLoupeFacet());
        address own   = address(new OwnershipFacet());
        address erc20 = address(new ERC20Facet());
        address burn  = address(new BurnableFacet());

        // Metadata contracts
        address mCut   = address(new DiamondCutFacetMetadata(cut));
        address mLoupe = address(new DiamondLoupeFacetMetadata(loupe));
        address mOwn   = address(new OwnershipFacetMetadata(own));
        address mERC20 = address(new ERC20FacetMetadata(erc20));
        address mBurn  = address(new BurnableFacetMetadata(burn));

        // Registry
        address[] memory validCuts = new address[](5);
        validCuts[0] = mCut;
        validCuts[1] = mLoupe;
        validCuts[2] = mOwn;
        validCuts[3] = mERC20;
        validCuts[4] = mBurn;
        Registry registry = new Registry(validCuts);

        // SPL factory (unused feature slots set to address(0))
        SPL.FeatureAddresses memory fa = SPL.FeatureAddresses({
            diamondCut: mCut, diamondLoupe: mLoupe, ownership: mOwn,
            erc20: mERC20, burnable: mBurn,
            extra: address(0), metadata: address(0), permit: address(0),
            crossChain: address(0), superchainERC20: address(0), oft: address(0),
            init: address(new DiamondInit())
        });
        SPL spl = new SPL(fa, address(registry));
        registry.setFactory(address(spl));

        // Create product: DiamondCut + DiamondLoupe + Ownership + ERC20 + Burnable
        address[] memory features = new address[](5);
        features[0] = mCut;
        features[1] = mLoupe;
        features[2] = mOwn;
        features[3] = mERC20;
        features[4] = mBurn;
        product = spl.createProduct(features, owner);
    }

    // -- Helpers --------------------------------------------------------------

    /// @dev Call burn() and return the gas consumed.
    function _burnDiamond(uint256 amount) internal returns (uint256 gasUsed) {
        vm.prank(user);
        uint256 before = gasleft();
        BurnableFacet(diamondProduct).burn(amount);
        gasUsed = before - gasleft();
    }

    function _burnPlain(uint256 amount) internal returns (uint256 gasUsed) {
        vm.prank(user);
        uint256 before = gasleft();
        plain.burn(amount);
        gasUsed = before - gasleft();
    }

    // -- Gas comparison tests -------------------------------------------------

    /// @notice Primary comparison: burn() gas on diamond vs plain.
    function test_GasComparison_Burn() public {
        uint256 gasDiamond = _burnDiamond(BURN_AMOUNT);
        uint256 gasPlain   = _burnPlain(BURN_AMOUNT);
        uint256 overhead   = gasDiamond > gasPlain ? gasDiamond - gasPlain : 0;

        console2.log("=== burn() gas comparison ===");
        console2.log("Diamond SPL product : ", gasDiamond, "gas");
        console2.log("Plain ERC20Burnable : ", gasPlain,   "gas");
        if (gasDiamond >= gasPlain) {
            console2.log("Diamond overhead    : +", overhead, "gas");
            console2.log("Overhead %          : ",
                overhead * 100 / (gasPlain == 0 ? 1 : gasPlain), "%");
        } else {
            console2.log("Plain overhead      : +", gasPlain - gasDiamond, "gas");
        }
    }

    /// @notice Measure burn() gas at different amounts to check linearity.
    function test_GasComparison_BurnAmounts() public {
        uint256[3] memory amounts = [uint256(1e18), uint256(10e18), uint256(100e18)];

        console2.log("=== burn() gas by amount ===");
        console2.log("Amount        | Diamond  | Plain    | Overhead");
        console2.log("------------- | -------- | -------- | --------");

        for (uint256 i = 0; i < amounts.length; i++) {
            // Remint after each burn so balances stay consistent
            vm.prank(owner);
            ERC20Facet(diamondProduct).mint(user, amounts[i]);
            vm.prank(owner);
            plain.mint(user, amounts[i]);

            uint256 gd = _burnDiamond(amounts[i]);
            uint256 gp = _burnPlain(amounts[i]);
            console2.log("  amount:", amounts[i] / 1e18, "e18");
            console2.log("  diamond:", gd, "| plain:", gp);
            console2.log("  overhead:", gd > gp ? gd - gp : 0);
        }
    }

    /// @notice Measure burnFrom() gas (requires an approval first).
    function test_GasComparison_BurnFrom() public {
        address spender = makeAddr("spender");

        // Approve on diamond
        vm.prank(user);
        ERC20Facet(diamondProduct).approve(spender, BURN_AMOUNT);

        // Approve on plain
        vm.prank(user);
        plain.approve(spender, BURN_AMOUNT);

        // Measure burnFrom on diamond
        vm.prank(spender);
        uint256 beforeD = gasleft();
        BurnableFacet(diamondProduct).burnFrom(user, BURN_AMOUNT);
        uint256 gasDiamond = beforeD - gasleft();

        // Measure burnFrom on plain
        vm.prank(spender);
        uint256 beforeP = gasleft();
        plain.burnFrom(user, BURN_AMOUNT);
        uint256 gasPlain = beforeP - gasleft();

        console2.log("=== burnFrom() gas comparison ===");
        console2.log("Diamond SPL product : ", gasDiamond, "gas");
        console2.log("Plain ERC20Burnable : ", gasPlain,   "gas");
        console2.log("Diamond overhead    : +",
            gasDiamond > gasPlain ? gasDiamond - gasPlain : 0, "gas");
    }

    // -- Sanity checks --------------------------------------------------------

    function test_DiamondBurnReducesBalance() public {
        _burnDiamond(BURN_AMOUNT);
        assertEq(ERC20Facet(diamondProduct).balanceOf(user), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(ERC20Facet(diamondProduct).totalSupply(),   MINT_AMOUNT - BURN_AMOUNT);
    }

    function test_PlainBurnReducesBalance() public {
        _burnPlain(BURN_AMOUNT);
        assertEq(plain.balanceOf(user), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(plain.totalSupply(),   MINT_AMOUNT - BURN_AMOUNT);
    }
}
