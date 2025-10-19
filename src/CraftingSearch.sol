// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ResourceNFT1155} from "./ResourceNFT1155.sol";
import {ItemNFT721} from "./ItemNFT721.sol";

contract CraftingSearch is AccessControl {
    ResourceNFT1155 public resources;
    ItemNFT721 public items;

    mapping(address => uint256) private lastSearchTime;
    uint256 public constant SEARCH_COOLDOWN = 60; // 60 seconds

    struct Recipe {
        uint256[] requiredResourceIds;
        uint256[] requiredAmounts;
        uint256 craftedItemId;
    }

    // Hardcoded Recipe 1: requires 1 unit of Resource ID 1 to craft Item ID 1
    Recipe internal recipe1 = Recipe(
        new uint256[](1),
        new uint256[](1),
        1
    );

    constructor(address admin, ResourceNFT1155 _resources, ItemNFT721 _items) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        resources = _resources;
        items = _items;
        
        recipe1.requiredResourceIds[0] = 1;
        recipe1.requiredAmounts[0] = 1;
    }
    
    /// @notice Generates a pseudo-random number between 1 and 3.
    function _pseudoRandom(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.chainid, msg.sender, seed))) % 3 + 1;
    }

    /// @notice Allows a player to search for resources once every 60 seconds. Mints 3 random ERC1155 resources.
    function search() external {
        require(block.timestamp >= lastSearchTime[msg.sender] + SEARCH_COOLDOWN, "Search cooldown not finished");
        
        lastSearchTime[msg.sender] = block.timestamp;

        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            ids[i] = _pseudoRandom(i); 
            amounts[i] = 1; 
        }

        resources.mintBatch(msg.sender, ids, amounts);
    }

    /// @notice Crafts an Item NFT (ERC721) by burning required ERC1155 resources.
    /// @param itemType The ID of the item to craft (hardcoded to 1).
    function craft(uint256 itemType) external {
        require(itemType == recipe1.craftedItemId, "Invalid item type or recipe ID");

        // Burn Resources (requires prior approval)
        resources.burnBatch(
            msg.sender, 
            recipe1.requiredResourceIds,
            recipe1.requiredAmounts
        );

        // Mint Item (requires MINTER_ROLE)
        items.mintTo(msg.sender);
    }
}