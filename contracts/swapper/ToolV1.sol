// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IRouter.sol";

contract ToolV1 is Initializable {
    using SafeMath for uint256;
    IRouter router;
    address recipientAddr;

    /**
     * Constructor
     * @param _recipient Address where fees will be sent
     */
    function initialize(address _recipient) public initializer {
        router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        recipientAddr = _recipient;
    }

    /**
     * Exchanges from ETH to tokens
     * @param _percentage Array containing the percentage of the tokens that need to be exchanged
     * @param tokens Array containing the address of the tokens to be exchanged for ETH
     */
    function swapETHToToken(
        uint256[] memory _percentage,
        address[] memory tokens
    ) public payable isValid(_percentage, tokens) {
        uint256 fee = (msg.value).div(1000);
        uint256 _value = (msg.value).sub(fee);
        uint256 amount = 0;
        address[] memory path = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);

        path[0] = router.WETH();

        for (uint256 i = 0; i < _percentage.length; i++) {
            if (_percentage[i] > 0) {
                amount = (_percentage[i].mul(_value)).div(100);
                path[1] = tokens[i];

                amountsOut = router.getAmountsOut(amount, path);

                // Exchange ETH for token1
                router.swapExactETHForTokens{value: amount}(
                    amountsOut[1],
                    path,
                    msg.sender,
                    block.timestamp
                );
            }
        }

        // Transfer fee to recipient
        payable(recipientAddr).transfer(fee);
    }

    /**
     * Modifier that checks if the function inputs are valid.
     * @param _percentage Array containing the percentage of the tokens that need to be exchanged
     * @param _address Array containing the address of the tokens to be exchanged for ETH
     */
    modifier isValid(uint256[] memory _percentage, address[] memory _address) {
        require(msg.value > 0, "Not enough ETH");
        require(_percentage.length == _address.length, "Data don't match");

        uint256 max = 0;

        for (uint256 i = 0; i < _percentage.length; i++) {
            max = max.add(_percentage[i]);
        }

        require(max == 100, "Invalid percentage");
        _;
    }
}
