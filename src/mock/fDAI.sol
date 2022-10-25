// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract fDAI is ERC20 {
    constructor() ERC20("fake DAI", "fDAI") {
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}