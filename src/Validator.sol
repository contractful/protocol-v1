//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

pragma solidity ^0.8.0;

contract Validator is AccessControlUpgradeable, PausableUpgradeable {

    string public constant name = "Contractful";
    mapping(uint256 => bool) public usedNonces;
    bytes32 public DOMAIN_SEPARATOR;

    function initialize_() public onlyInitializing() {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /**
    * @notice checks whether the signer signed the description
     */
    function validateDescription(
        address signer,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata description,
        uint256 nonce
    ) public returns (bool) {
        require(!usedNonces[nonce]);
        usedNonces[nonce] = true;

        bytes32 message = keccak256(
            abi.encode(
                keccak256(
                    "Signature(string description, uint256 nonce)"
                ),
                description,
                nonce
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, message)
        );

        address recovered = ecrecover(digest, v, r, s);
        return signer != address(0) && signer == recovered;
    }
}