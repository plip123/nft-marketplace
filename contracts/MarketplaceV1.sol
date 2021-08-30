//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";

contract MarketplaceV1 is Initializable, OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Item {
        uint256 id;
        address vendor;
        uint256 price;
        uint256 quantity;
        bool available;
    }

    address private adminAddr;
    address recipientAddr;
    uint256 fee;
    Item[] private items;
    mapping(address => mapping(uint256 => uint256)) public offerts;

    event SellItem(address vendor, uint256 id, uint256 price, uint256 quantity);
    event BuyItem(
        address vendor,
        address seller,
        uint256 id,
        uint256 price,
        uint256 quantity
    );
    event CancelOffer(address vendor, uint256 id);

    /**
     * Constructor
     *
     */
    function initialize(address _admin, address _recipient) public initializer {
        adminAddr = _admin;
        recipientAddr = _recipient;
        fee = 1;
    }

    /**
     * Buy a marketplace item
     * @param itemId ID of the item to buy
     * @param vendorAddr Vendor's address
     * @param tokenAddr ERC20 token address
     */
    function buyItem(
        uint256 itemId,
        address vendorAddr,
        address tokenAddr
    ) public payable {
        console.log(itemId, vendorAddr, tokenAddr);
        // require(itemToken.ownerOf(itemId) != msg.sender, "You are the owner");
        Item storage item = items[offerts[vendorAddr][itemId]];

        require(item.available, "Product not in stock");
        item.available = false;

        emit BuyItem(
            item.vendor,
            msg.sender,
            itemId,
            item.price,
            item.quantity
        );
    }

    /**
     * Allows a vendor to sell an item in the marketplace
     * @param tokenId ID of the token to sell
     * @param price item price
     * @param quantity number of items to sell
     */
    function sellItem(
        uint256 tokenId,
        uint256 price,
        uint256 quantity
    ) public {
        // require(
        //     itemToken.ownerOf(tokenId) == msg.sender,
        //     "You are not the owner"
        // );
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Quantity must be greater than 0");
        // require(
        //     itemToken.getApproved(tokenId) == address(this),
        //     "This item has not yet been approved"
        // );

        items.push(Item(tokenId, msg.sender, price, quantity, true));
        offerts[msg.sender][tokenId] = items.length.sub(1);

        emit SellItem(msg.sender, tokenId, price, quantity);
    }

    /**
     * Allows you to cancel an offer
     * @param itemId ID of the item to cancel
     */
    function cancelOffer(uint256 itemId) public {
        uint256 index = offerts[msg.sender][itemId];
        require(items[index].vendor == msg.sender, "You are not the owner");

        delete items[index];
        delete offerts[msg.sender][itemId];

        emit CancelOffer(msg.sender, itemId);
    }

    /**
     * Returns all items from the marketplace
     * @return Returns an array of items
     */
    function getAllItems() public view returns (Item[] memory) {
        return items;
    }

    /**
     * Change the purchase fee
     * @param newFee new fee amount
     */
    function setFee(uint256 newFee) public isAdmin {
        fee = newFee;
    }

    /**
     * Change the fee container
     * @param _recipient address of the new fee's recipient
     */
    function setRecipientFee(address _recipient) public isAdmin {
        recipientAddr = _recipient;
    }

    /**
     * Obtains the recipient's address and the amount of the current fee.
     */
    function getFeeConfig() public view isAdmin returns (address, uint256) {
        return (recipientAddr, fee);
    }

    /**
     * Check if the sender is admin
     */
    modifier isAdmin() {
        require(adminAddr == msg.sender, "You are not the admin");
        _;
    }
}
