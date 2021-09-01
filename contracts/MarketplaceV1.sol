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
    address constant linkAddr = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address constant daiAddr = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 fee;
    IERC20 LINK;
    IERC20 DAI;
    AggregatorV3Interface internal priceFeedUSD;
    AggregatorV3Interface internal priceFeedDAI;
    AggregatorV3Interface internal priceFeedLINK;
    Item[] internal items;
    mapping(address => mapping(uint256 => uint256)) public offerts;

    // Events
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

        DAI = IERC20(daiAddr);
        LINK = IERC20(linkAddr);
        priceFeedUSD = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        priceFeedLINK = AggregatorV3Interface(
            0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c
        );
        priceFeedDAI = AggregatorV3Interface(
            0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9
        );
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
        getLatestPrice(tokenAddr);
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
        address tokenAddr,
        uint256 tokenId,
        uint256 price,
        uint256 quantity
    ) public {
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Can not sell 0 tokens");
        require(
            IERC1155(tokenAddr).balanceOf(msg.sender, tokenId) >= quantity,
            "You do not have enough tokens"
        );
        if (IERC1155(tokenAddr).isApprovedForAll(msg.sender, address(this))) {
            console.log("Approved");
        } else {
            console.log("Not approved");
        }

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
     * Get current WEI price per USD, DAI or LINK value in ETH
     */
    function getLatestPrice(address tokenAddr) public view returns (uint256) {
        int256 price;

        if (tokenAddr == linkAddr) {
            (, price, , , ) = priceFeedLINK.latestRoundData();
        } else if (tokenAddr == daiAddr) {
            (, price, , , ) = priceFeedDAI.latestRoundData();
        } else {
            (, price, , , ) = priceFeedUSD.latestRoundData();
        }

        //price = 10**26 / price;
        return uint256(price);
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
