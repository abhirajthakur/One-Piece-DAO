// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private _number;

    event NumberChanged(uint256 number);

    function getNumber() external view returns (uint256) {
        return _number;
    }

    function store(uint256 newNumber) public onlyOwner {
        _number = newNumber;
    }
}
