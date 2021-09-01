//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTToken is ERC1155, Ownable {
    string[] public tokens;

    /// @notice constructor
    constructor() public ERC1155("") {}

    /// @notice Creates a new token and assigns it to an owner
    function createToken(
        string memory _name,
        uint256 _amount,
        address _to
    ) public onlyOwner {
        //Mint new token and make sender the owner
        tokens.push(_name);
        uint256 _newTokenId = tokens.length - 1;
        _mint(_to, _newTokenId, _amount, "");
    }
}
