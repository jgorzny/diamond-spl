// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibERC20} from "../libraries/LibERC20.sol";
import {LibPermit} from "../libraries/LibPermit.sol";

/// @title PermitFacet
/// @notice Optional feature (sub-feature of Extra): ERC20-Permit (EIP-2612).
/// Storage for nonces is isolated in LibPermit. Uses ERC20 storage for allowances.
contract PermitFacet {
    // EIP-712 typehash
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "PermitFacet: expired deadline");
        LibPermit.Storage storage ps = LibPermit.layout();
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, ps.nonces[owner]++, deadline));
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
        address signer = ecrecover(hash, v, r, s);
        require(signer == owner && signer != address(0), "PermitFacet: invalid signature");
        LibERC20._approve(owner, spender, value);
    }

    function nonces(address owner) external view returns (uint256) {
        return LibPermit.layout().nonces[owner];
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("SPLDiamond")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
}
