// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ItemNFT721 (Final)
 * @notice Implements role-gated mint and burn functions for Marketplace usage.
 */
contract ItemNFT721 is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // assign to CraftingSearch
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE"); // assign to Marketplace
    uint256 public nextId = 1;

    constructor(address admin) ERC721("Cossack Items", "CITEM") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mints a new Item NFT and increments the token ID counter.
    /// @param to The recipient address.
    /// @return The ID of the newly minted token.
    function mintTo(
        address to
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 id = nextId++;
        _safeMint(to, id);
        return id;
    }
    
    /// @notice Allows the BURNER_ROLE (Marketplace) to burn an item.
    /// @param tokenId The ID of the item to burn.
    function burnItem(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}