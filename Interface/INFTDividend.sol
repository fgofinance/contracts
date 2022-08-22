// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTDividend {
    function addTokenId(uint256 tokenId) external;

    function removeTokenId(uint256 tokenId) external;
}
