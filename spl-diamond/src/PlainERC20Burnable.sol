// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PlainERC20Burnable
/// @notice Monolithic ERC-20 with burn — used as the gas-comparison baseline.
/// Implements exactly the same token semantics as the diamond SPL product
/// (ERC20Facet + BurnableFacet) but in a single contract with no proxy overhead.
contract PlainERC20Burnable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        owner = msg.sender;
    }

    // ── ERC-20 core ───────────────────────────────────────────────────────────

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function allowance(address account, address spender) external view returns (uint256) {
        return _allowances[account][spender];
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "PlainERC20: only owner");
        _mint(to, amount);
    }

    // ── Burnable ──────────────────────────────────────────────────────────────

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to zero address");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "ERC20: burn from zero address");
        require(_balances[from] >= amount, "ERC20: burn amount exceeds balance");
        _balances[from] -= amount;
        _totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        require(_balances[from] >= amount, "ERC20: insufficient balance");
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address from, address spender, uint256 amount) internal {
        require(from != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[from][spender] = amount;
        emit Approval(from, spender, amount);
    }

    function _spendAllowance(address from, address spender, uint256 amount) internal {
        uint256 current = _allowances[from][spender];
        if (current != type(uint256).max) {
            require(current >= amount, "ERC20: insufficient allowance");
            _allowances[from][spender] = current - amount;
        }
    }
}
