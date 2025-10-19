// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ItemNFT721} from "./ItemNFT721.sol";
import {MagicToken} from "./MagicToken.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol"; 

contract Marketplace is AccessControl {
    ItemNFT721 public items;
    MagicToken public magic;

    struct Listing {
        address seller;
        uint256 price; // Price in MagicToken units
        bool isListed;
    }
    mapping(uint256 => Listing) public listings;

    bytes32 public constant MAGIC_MINTER_ROLE = keccak256("MARKET_ROLE"); 

    event ItemListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ItemDelisted(uint256 indexed tokenId);
    event ItemPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);


    constructor(address admin, ItemNFT721 _items, MagicToken _magic) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        items = _items;
        magic = _magic;
    }

    /// @notice Lists an Item NFT for sale. The token remains with the seller.
    /// @param tokenId The ID of the Item NFT to list.
    /// @param price The price in MagicToken.
    function list(uint256 tokenId, uint256 price) external {
        require(items.ownerOf(tokenId) == msg.sender, "Caller is not the owner of the item");
        require(listings[tokenId].isListed == false, "Item is already listed");
        require(price > 0, "Price must be greater than zero");

        require(items.getApproved(tokenId) == address(this), "Marketplace must be approved to transfer the item");

        listings[tokenId] = Listing({ 
            seller: msg.sender,
            price: price,
            isListed: true
        });

        emit ItemListed(tokenId, msg.sender, price); 
    }
    
    /// @notice Allows the seller to remove the listing.
    /// @param tokenId The ID of the item to delist.
    function delist(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        
        require(listing.isListed, "Item is not listed");
        require(items.ownerOf(tokenId) == listing.seller, "Item must be owned by seller");
        require(listing.seller == msg.sender, "Only the seller can delist");

        delete listings[tokenId];

        emit ItemDelisted(tokenId);
    }

    /// @notice Executes item purchase: burns ERC721 and mints MAGIC to seller.
    /// @param tokenId The ID of the item to purchase.
    function purchase(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        
        require(listing.isListed, "Item is not listed");
        require(listing.seller != msg.sender, "Cannot purchase your own item");
        
        // A) Burn the Item NFT (calls ItemNFT721.burnItem which requires BURNER_ROLE)
        items.burnItem(tokenId); 

        // B) Mint MagicToken to the Seller 
        magic.mint(listing.seller, listing.price);

        // 3. Finalize
        delete listings[tokenId];
        
        emit ItemPurchased(tokenId, msg.sender, listing.seller, listing.price); 
    }
}