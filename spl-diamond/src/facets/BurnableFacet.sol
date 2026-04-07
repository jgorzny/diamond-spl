// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibERC20} from "../libraries/LibERC20.sol";

/// @title BurnableFacet
/// @notice Optional feature: token burning.
/// Reads and writes ERC20 storage via LibERC20 (shared with ERC20Facet).
/// Required by the SuperchainERC20 feature (constraint: SuperchainERC20 => Burnable).
contract BurnableFacet {
    function burn(uint256 amount) external {
        LibERC20._burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        LibERC20._spendAllowance(account, msg.sender, amount);
        LibERC20._burn(account, amount);
    }
}
