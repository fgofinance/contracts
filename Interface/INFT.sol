// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFT {
    function ownerOf(uint256) external view returns (address);

    function getLevel(uint256) external view returns (uint256);

    function mint(address to, uint256 nftLevel) external;

    function mintByInvite(address to) external;
}
