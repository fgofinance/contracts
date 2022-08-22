// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Interface/INFTDividend.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract FGONFT is Initializable, Ownable, ERC721Enumerable {
    string private _name;
    string private _symbol;
    uint256 private _nextTokenId;
    mapping(uint256 => uint256) private _levels;

    bool public transferEnabled;
    address public daoAddress;
    address public luckyAddress;
    address public dividendAddress;

    constructor() ERC721("", "") {}

    function initialize() public initializer {
        _nextTokenId = 1;
        _name = "KY NFT";
        _symbol = "KY NFT";
        _transferOwnership(_msgSender());
    }

    function setAddress(
        address _dao,
        address _lucky,
        address _dividend
    ) public onlyOwner {
        daoAddress = _dao;
        luckyAddress = _lucky;
        dividendAddress = _dividend;
    }

    function setTransferEnabled(bool _enabled) external onlyOwner {
        transferEnabled = _enabled;
    }

    function getLevel(uint256 tokenId) public view virtual returns (uint256) {
        super._requireMinted(tokenId);
        return _levels[tokenId];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (from != address(0) && to != address(0)) {
            require(
                transferEnabled,
                "Error: The current NFT cannot be transferred"
            );
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._afterTokenTransfer(from, to, tokenId);
    }

    function addNftDividend(uint256 tokenId) external onlyOwner {
        INFTDividend(dividendAddress).addTokenId(tokenId);
    }

    function removeNftDividend(uint256 tokenId) external onlyOwner {
        INFTDividend(dividendAddress).removeTokenId(tokenId);
    }

    function mintByInvite(address to) external {
        require(
            _msgSender() == daoAddress,
            "Error: No permission to execute this method"
        );
        _levels[_nextTokenId] = 1;
        super._mint(to, _nextTokenId);
        _nextTokenId++;
    }

    function mint(address to, uint256 nftLevel) external {
        require(nftLevel > 0 && nftLevel < 4, "Error: Mint NFT grade anomaly");
        require(
            _msgSender() == luckyAddress,
            "Error: No permission to execute this method"
        );
        _levels[_nextTokenId] = nftLevel;
        super._mint(to, _nextTokenId);
        _nextTokenId++;
    }
}
