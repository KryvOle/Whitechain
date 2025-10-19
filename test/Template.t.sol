// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ResourceNFT1155} from "../src/ResourceNFT1155.sol";
import {ItemNFT721} from "../src/ItemNFT721.sol";
import {MagicToken} from "../src/MagicToken.sol";
import {CraftingSearch} from "../src/CraftingSearch.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract TemplateTest is Test {
    ResourceNFT1155 res;
    ItemNFT721 items;
    MagicToken magic;
    CraftingSearch cs;
    Marketplace mkt;

    address admin = address(0xA11CE);

    function setUp() public {
        res = new ResourceNFT1155(admin);
        items = new ItemNFT721(admin);
        magic = new MagicToken(admin);
        cs = new CraftingSearch(admin, res, items);
        mkt = new Marketplace(admin, items, magic);

        // wire roles (mirrors Deploy.s.sol)
        vm.startPrank(admin);
        res.grantRole(res.MINTER_ROLE(), address(cs));
        res.grantRole(res.BURNER_ROLE(), address(cs));
        items.grantRole(items.MINTER_ROLE(), address(cs));
        items.grantRole(items.BURNER_ROLE(), address(mkt)); // Grant BURNER_ROLE to Marketplace
        magic.grantRole(magic.MARKET_ROLE(), address(mkt));
        vm.stopPrank();
    }

    function test_deployed_and_roles_wired() public {
        // contracts deployed
        assertTrue(address(res) != address(0));
        assertTrue(address(items) != address(0));
        assertTrue(address(magic) != address(0));
        assertTrue(address(cs) != address(0));
        assertTrue(address(mkt) != address(0));

        // core roles wired
        assertTrue(res.hasRole(res.MINTER_ROLE(), address(cs)));
        assertTrue(res.hasRole(res.BURNER_ROLE(), address(cs)));
        assertTrue(items.hasRole(items.MINTER_ROLE(), address(cs)));
        assertTrue(magic.hasRole(magic.MARKET_ROLE(), address(mkt)));
    }

    address user1 = address(1);
    address user2 = address(2);
    uint256 public constant RESOURCE_ID_1 = 1;
    uint256 public constant ITEM_ID_1 = 1;
    uint256 public constant MARKET_PRICE = 100 ether; // MagicToken price

    // --- 1. Search Tests ---
    
    function test_search_mints_3_resources() public {
        vm.startPrank(user1);
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN());
        
        assertEq(res.balanceOf(user1, RESOURCE_ID_1), 0, "Initial balance must be zero");
        
        cs.search();
        
        uint256 totalMinted = res.balanceOf(user1, 1) + res.balanceOf(user1, 2) + res.balanceOf(user1, 3);
        assertEq(totalMinted, 3, "Should mint exactly 3 resources");
        
        vm.stopPrank();
    }
    
    function test_search_cooldown_works() public {
        vm.startPrank(user1);

        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN());
        
        cs.search();
        
        vm.expectRevert("Search cooldown not finished"); 
        cs.search();
        
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN());
        
        cs.search();
        
        vm.stopPrank();
    }


    // --- 2. Craft Tests ---

    function test_craft_success() public {
        vm.startPrank(user1);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = RESOURCE_ID_1;
        amounts[0] = 1;

        // User receives Resource ID 1 (via CS)
        vm.stopPrank(); 
        vm.startPrank(address(cs)); 
        res.mintBatch(user1, ids, amounts); 
        vm.stopPrank();
        vm.startPrank(user1); // Revert to user1

        assertEq(items.balanceOf(user1), 0, "Initial item balance must be zero");

        // Approve CS to burn resources
        res.setApprovalForAll(address(cs), true);
        
        // Craft Item ID 1
        cs.craft(ITEM_ID_1);

        // Assert: 
        assertEq(res.balanceOf(user1, RESOURCE_ID_1), 0, "Resource must be burned");
        assertEq(items.balanceOf(user1), 1, "Item must be minted");
        
        vm.stopPrank();
    }

    function test_craft_fail_no_resources() public {
        vm.startPrank(user1);
        
        // Approve CS to burn, but no resources
        res.setApprovalForAll(address(cs), true);
        
        // Expect revert due to insufficient balance
        vm.expectRevert(); 
        cs.craft(ITEM_ID_1);
        
        vm.stopPrank();
    }

    
    // --- 3. Marketplace Tests ---

    function test_marketplace_listing_and_delisting() public {
        vm.startPrank(user1);

        // User 1 receives Item NFT (ID 1)
        vm.stopPrank(); 
        vm.startPrank(address(cs)); 
        items.mintTo(user1); 
        vm.stopPrank();
        vm.startPrank(user1); // Revert to user1

        uint256 mintedTokenId = 1; 

        // Listing
        items.approve(address(mkt), mintedTokenId);
        mkt.list(mintedTokenId, MARKET_PRICE);

        // Check: Item remains with seller, listing exists
        (,,bool isListed) = mkt.listings(mintedTokenId);
        assertTrue(isListed, "Item must be listed");
        assertEq(items.ownerOf(mintedTokenId), user1, "Item must remain with seller after listing");

        // Delisting
        mkt.delist(mintedTokenId);
        
        // Check: Listing removed
        (,,isListed) = mkt.listings(mintedTokenId);
        assertFalse(isListed, "Item must be delisted");
        assertEq(items.ownerOf(mintedTokenId), user1, "Item must still be owned by seller");
        
        vm.stopPrank();
    }

    function test_marketplace_purchase_success() public {
        // A. Arrange: User1 (Seller) lists item
        vm.startPrank(user1);
        vm.stopPrank();
        vm.startPrank(address(cs));
        items.mintTo(user1); 
        vm.stopPrank();
        vm.startPrank(user1); // Revert to user1
        
        uint256 listedTokenId = 1; 
        items.approve(address(mkt), listedTokenId);
        mkt.list(listedTokenId, MARKET_PRICE);
        vm.stopPrank();

        assertEq(magic.balanceOf(user1), 0, "Seller magic balance must be zero initially");
        
        // B. Act: User2 (Buyer) buys item
        vm.startPrank(user2);
        
        // EXECUTE PURCHASE (burns item)
        mkt.purchase(listedTokenId); 
        
        vm.stopPrank();
        
        // C. Assert: 
        // 1. Item NFT must be BURNED: Check that the token ID is now invalid
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", listedTokenId)); 
        items.ownerOf(listedTokenId); 
        
        // 2. Seller received MagicToken
        assertEq(magic.balanceOf(user1), MARKET_PRICE, "Seller must receive MagicToken");
        
        // 3. Listing must be REMOVED
        (,,bool isListedAfterPurchase) = mkt.listings(listedTokenId);
        assertFalse(isListedAfterPurchase, "Listing must be removed after purchase"); 
    }
}
