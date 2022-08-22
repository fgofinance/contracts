// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMathUint.sol";
import "./SafeMathInt.sol";
import "../Interface/INFT.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTDividend is Initializable, Ownable {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    uint256 internal constant magnitude = 2**128;

    uint256 private _perValue;
    uint256 private _totalBalance;
    uint8[] private _levelShares;
    mapping(uint256 => uint256) private _shareBalances;

    uint256 private magnifiedDividendPerShare;
    mapping(uint256 => int256) private magnifiedDividendCorrections;
    mapping(uint256 => uint256) private withdrawnDividends;

    address public tokenAddress;
    address public nftAddress;
    uint256 public totalDividendsDistributed;

    mapping(uint256 => uint256) public lastClaimTimes;
    uint256 public claimWait;

    event DividendsDistributed(address indexed from, uint256 amount);
    event DividendClaim(address indexed to, uint256 amount);

    function initialize() public initializer {
        _perValue = 100;
        _levelShares = [150, 150, 200];
        _transferOwnership(_msgSender());

        claimWait = 24 * 3600;
    }

    function setAddress(address _token, address _nft) public onlyOwner {
        tokenAddress = _token;
        nftAddress = _nft;
    }

    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        claimWait = newClaimWait;
    }

    function addPerValue(uint256 perValue) external onlyOwner {
        _perValue = perValue;
    }

    function withdrawableDividendOf(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return accumulativeDividendOf(tokenId).sub(withdrawnDividends[tokenId]);
    }

    function withdrawnDividendOf(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return withdrawnDividends[tokenId];
    }

    function accumulativeDividendOf(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return
            magnifiedDividendPerShare
                .mul(_shareBalances[tokenId])
                .toInt256Safe()
                .add(magnifiedDividendCorrections[tokenId])
                .toUint256Safe() / magnitude;
    }

    function distributeDividends(uint256 amount) public {
        if (_msgSender() != tokenAddress) return;
        if (_totalBalance == 0) return;
        if (amount == 0) return;
        magnifiedDividendPerShare = magnifiedDividendPerShare.add(
            (amount).mul(magnitude) / _totalBalance
        );
        emit DividendsDistributed(msg.sender, amount);
        totalDividendsDistributed = totalDividendsDistributed.add(amount);
    }

    function addTokenId(uint256 tokenId) public {
        if (_msgSender() != nftAddress) return;
        uint256 level = INFT(nftAddress).getLevel(tokenId);
        if (level == 0 || level > 4) return;
        uint256 value = _perValue.mul(_levelShares[level.sub(1)]);
        _shareBalances[tokenId] = _shareBalances[tokenId].add(value);
        _totalBalance = _totalBalance.add(value);

        magnifiedDividendCorrections[tokenId] = magnifiedDividendCorrections[
            tokenId
        ].sub((magnifiedDividendPerShare.mul(value)).toInt256Safe());
    }

    function removeTokenId(uint256 tokenId) public {
        if (_msgSender() != nftAddress) return;
        uint256 level = INFT(nftAddress).getLevel(tokenId);
        if (level == 0 || level > 4) return;
        uint256 value = _perValue.mul(_levelShares[level.sub(1)]);
        if (value > _shareBalances[tokenId]) {
            value = _shareBalances[tokenId];
        }
        _shareBalances[tokenId] = _shareBalances[tokenId].sub(value);
        if (value > _totalBalance) {
            value = _totalBalance;
        }
        _totalBalance = _totalBalance.sub(value);

        magnifiedDividendCorrections[tokenId] = magnifiedDividendCorrections[
            tokenId
        ].add((magnifiedDividendPerShare.mul(value)).toInt256Safe());
    }

    function claim(uint256 tokenId) public virtual {
        uint256 lastClaimTime = lastClaimTimes[tokenId];
        require(
            block.timestamp.sub(claimWait) >= lastClaimTime,
            "Error: You need to wait for the claim time to arrive"
        );
        address _sender = _msgSender();
        address nftOwner = INFT(nftAddress).ownerOf(tokenId);
        require(
            nftOwner != address(0) && nftOwner == _sender,
            "Error: You do not own this NFT"
        );
        uint256 _withdrawableDividend = withdrawableDividendOf(tokenId);
        require(
            _withdrawableDividend > 0,
            "Error: No token balance currently available for withdrawal"
        );
        withdrawnDividends[tokenId] = withdrawnDividends[tokenId].add(
            _withdrawableDividend
        );
        IERC20(tokenAddress).transfer(_sender, _withdrawableDividend);
        lastClaimTimes[tokenId] = block.timestamp;
        emit DividendClaim(_sender, _withdrawableDividend);
    }

    function claimOut(
        address payable to,
        address token,
        uint256 amount
    ) public onlyOwner {
        if (token == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(
                success,
                "Error: unable to send value, to may have reverted"
            );
        } else IERC20(token).transfer(to, amount);
    }
}
