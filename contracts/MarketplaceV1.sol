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
        address token;
        address vendor;
        uint256 price;
        uint256 quantity;
        uint256 deadline;
        bool available;
    }

    address private adminAddr;
    address recipientAddr;
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

        DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
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
     * Allows a vendor to sell an item in the marketplace
     * @param tokenAddr ERC1155 token address
     * @param tokenId ID of the token to sell
     * @param price item price
     * @param deadline deadline of sell
     * @param quantity number of items to sell
     */
    function sellItem(
        address tokenAddr,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        uint256 quantity
    ) public {
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Can not sell 0 tokens");
        require(deadline > 0, "Time must be greater than 0");
        require(
            IERC1155(tokenAddr).balanceOf(msg.sender, tokenId) >= quantity,
            "You do not have enough tokens"
        );
        require(
            IERC1155(tokenAddr).isApprovedForAll(msg.sender, address(this)),
            "No permissions on tokens"
        );

        items.push(
            Item(
                tokenId,
                tokenAddr,
                msg.sender,
                price,
                quantity,
                block.timestamp.add(deadline),
                true
            )
        );

        offerts[msg.sender][tokenId] = items.length.sub(1);

        emit SellItem(msg.sender, tokenId, price, quantity);
    }

    /**
     * Allows you to cancel an offer
     * @param itemId ID of the item to cancel
     */
    function cancelOffer(uint256 itemId) public {
        Item storage item = items[offerts[msg.sender][itemId]];
        require(item.vendor == msg.sender, "You are not the owner");
        item.available = false;

        emit CancelOffer(msg.sender, itemId);
    }

    /**
     * Buy a marketplace item.
     * @notice If you use ETH as a payment method, you must pass by tokenAddr the following address 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
     * @param itemId ID of the item to buy
     * @param tokenAddr Address of currency of payment
     * @param vendorAddr Address of vendor item
     */
    function buyItem(
        uint256 itemId,
        address tokenAddr,
        address vendorAddr
    ) public payable {
        Item storage item = items[offerts[vendorAddr][itemId]];
        require(item.vendor != msg.sender, "You are the owner");
        require(item.available, "Product not in stock");
        require(item.deadline >= block.timestamp, "Product not in stock");
        uint256 amount = getLatestPrice(tokenAddr, item.price);
        uint256 feeAmount = (amount.mul(fee)).div(100);
        uint256 total = amount = amount.sub(feeAmount);

        if (tokenAddr != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            require(
                IERC20(tokenAddr).balanceOf(msg.sender) >= amount,
                "Balance not enough"
            );
            item.available = false;

            // PAY
            IERC20(tokenAddr).safeTransferFrom(msg.sender, item.vendor, total);

            // FEE
            IERC20(tokenAddr).safeTransferFrom(
                msg.sender,
                recipientAddr,
                feeAmount
            );
        } else {
            require(msg.value >= amount, "Balance not enough");
            item.available = false;

            payable(msg.sender).transfer(uint256(msg.value).sub(amount));
            payable(item.vendor).transfer(total);
            payable(recipientAddr).transfer(feeAmount);
        }

        // Transfer NFT token
        IERC1155(item.token).safeTransferFrom(
            item.vendor,
            msg.sender,
            item.id,
            item.quantity,
            ""
        );

        emit BuyItem(
            item.vendor,
            msg.sender,
            itemId,
            item.price,
            item.quantity
        );
    }

    /**
     * Get current WEI price per USD, DAI or LINK value in ETH
     */
    function getLatestPrice(address tokenAddr, uint256 amount)
        public
        view
        returns (uint256)
    {
        int256 price;

        if (tokenAddr == 0x514910771AF9Ca656af840dff83E8264EcF986CA) {
            (, price, , , ) = priceFeedLINK.latestRoundData();
        } else if (tokenAddr == 0x6B175474E89094C44Da98b954EedeAC495271d0F) {
            (, price, , , ) = priceFeedDAI.latestRoundData();
        } else {
            (, price, , , ) = priceFeedUSD.latestRoundData();
        }

        price = 10**26 / price;
        amount = amount.div(uint256(price));
        return uint256(amount);
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
