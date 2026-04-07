// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibERC20} from "../libraries/LibERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/// @title ERC20Facet
/// @notice Mandatory ERC-20 core feature: balances, transfers, allowances.
/// This facet is always required in the product line feature model.
/// Storage is isolated via diamond storage (LibERC20) to prevent collisions.
contract ERC20Facet {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256) {
        return LibERC20.layout().totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return LibERC20.layout().balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        LibERC20._transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        LibERC20._spendAllowance(from, msg.sender, amount);
        LibERC20._transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        LibERC20._approve(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return LibERC20.layout().allowances[owner][spender];
    }

    /// @notice Mint tokens — restricted to owner, used during product initialization
    function mint(address to, uint256 amount) external {
        LibDiamond.enforceIsContractOwner();
        LibERC20._mint(to, amount);
    }
}
