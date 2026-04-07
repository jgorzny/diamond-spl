// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibERC20} from "../libraries/LibERC20.sol";

/// @title OFTFacet
/// @notice Optional feature (xor sub-feature of CrossChain): LayerZero Omnichain Fungible Token.
/// Mutually exclusive with SuperchainERC20Facet (xor constraint enforced by isValidProduct).
/// Uses ERC20 storage for token operations.
///
/// NOTE: In production this integrates with LayerZero endpoints.
/// This prototype demonstrates the pattern and storage isolation.
contract OFTFacet {
    bytes32 constant OFT_STORAGE_POSITION = keccak256("diamond.storage.oft");

    struct OFTStorage {
        address lzEndpoint;
        mapping(uint16 => bytes) trustedRemotes;
    }

    function _oftStorage() internal pure returns (OFTStorage storage s) {
        bytes32 position = OFT_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    event SendToChain(uint16 indexed dstChainId, address indexed from, bytes32 toAddress, uint256 amount);
    event ReceiveFromChain(uint16 indexed srcChainId, address indexed to, uint256 amount);

    /// @notice Estimate the LayerZero messaging fee for a cross-chain send
    function estimateSendFee(
        uint16 dstChainId,
        bytes32 toAddress,
        uint256 amount,
        bool useZro,
        bytes calldata adapterParams
    ) external view returns (uint256 nativeFee, uint256 zroFee) {
        // Stub: real implementation calls lzEndpoint.estimateFees
        nativeFee = 0.001 ether;
        zroFee = 0;
    }

    /// @notice Burn tokens locally and send a cross-chain message via LayerZero
    function sendFrom(
        address from,
        uint16 dstChainId,
        bytes32 toAddress,
        uint256 amount,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes calldata adapterParams
    ) external payable {
        LibERC20._spendAllowance(from, msg.sender, amount);
        LibERC20._burn(from, amount);
        emit SendToChain(dstChainId, from, toAddress, amount);
        // Real implementation: lzEndpoint.send{value: msg.value}(...)
    }

    /// @notice Called by LayerZero endpoint to mint tokens on the destination chain
    function lzReceive(uint16 srcChainId, bytes calldata srcAddress, uint64 nonce, bytes calldata payload) external {
        require(msg.sender == _oftStorage().lzEndpoint, "OFTFacet: only endpoint");
        (address to, uint256 amount) = abi.decode(payload, (address, uint256));
        LibERC20._mint(to, amount);
        emit ReceiveFromChain(srcChainId, to, amount);
    }

    function setLzEndpoint(address endpoint) external {
        _oftStorage().lzEndpoint = endpoint;
    }

    function lzEndpoint() external view returns (address) {
        return _oftStorage().lzEndpoint;
    }
}
