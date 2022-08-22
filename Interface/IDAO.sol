// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IDAO {
    function getParent(address user) external view returns (address);
}
