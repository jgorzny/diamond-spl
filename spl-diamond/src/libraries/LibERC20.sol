// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibERC20
/// @notice Diamond storage for core ERC20 state (balances, allowances, supply).
/// Stored at a unique slot to avoid collisions with other facets.
library LibERC20 {
    bytes32 constant ERC20_STORAGE_POSITION = keccak256("diamond.storage.erc20.core");

    struct Storage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
    }

    function layout() internal pure returns (Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to zero address");
        Storage storage s = layout();
        s.totalSupply += amount;
        s.balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "ERC20: burn from zero address");
        Storage storage s = layout();
        require(s.balances[from] >= amount, "ERC20: burn amount exceeds balance");
        s.balances[from] -= amount;
        s.totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        Storage storage s = layout();
        require(s.balances[from] >= amount, "ERC20: insufficient balance");
        s.balances[from] -= amount;
        s.balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        layout().allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        Storage storage s = layout();
        uint256 currentAllowance = s.allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            s.allowances[owner][spender] = currentAllowance - amount;
        }
    }
}
