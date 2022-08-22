// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../Interface/IDAO.sol";
import "../Interface/INFT.sol";
import "./VRFConsumerBaseV2.sol";
import "./VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract FGOLuckyDraw is
    VRFConsumerBaseV2,
    Initializable,
    Ownable,
    ReentrancyGuard
{
    using Address for address;
    using SafeMath for uint256;

    uint256 private _payAmount;
    uint256[] private _returnPercents;

    address public daoAddress;
    address public nftAddress;

    uint256[] public prizes;
    mapping(uint256 => uint256) public nftLevels;
    uint256[] public prizeCounts;
    uint256[] public prizeMaxCounts;

    mapping(address => uint256) targets;
    mapping(address => uint256) public results;
    address[] public resultUsers;

    // chain link vrf
    bytes32 private keyHash;
    uint64 private s_subscriptionId;
    uint32 private callbackGasLimit;
    uint16 private requestConfirmations;
    uint32 private numWords;
    VRFCoordinatorV2Interface private COORDINATOR;

    uint256[] private _randoms;
    uint256 private _requestId;

    function initialize() public initializer {
        // MATIC
        vrfCoordinator = 0xAE975071Be8F8eE67addBC1A82488F1C24858067;
        keyHash = 0x6e099d640cde6de9d40ac749b4b594126b0169747122711109c9985d47751f93;

        // // BSC
        // vrfCoordinator = 0xc587d9053cd1118f25F645F9E08BB98c9712A4EE;
        // bytes32 key_hash  = 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04;

        _setChainLink(2000000, 3, 2, 226);

        _payAmount = (1 * 10**18) / 1000;
        // _payAmount = (1 * 10**18) / 2;
        _returnPercents = [1000, 500];

        prizes = [1, 2, 3, 4, 5, 6, 7];
        nftLevels[5] = 1;
        nftLevels[6] = 2;
        nftLevels[7] = 3;
        prizeCounts = [0, 0, 0, 0, 0, 0, 0];
        prizeMaxCounts = [4, 4, 4, 3, 3, 2, 1];
        // prizeMaxCounts = [14700, 1500, 300, 100, 160, 30, 10];
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);

        _transferOwnership(_msgSender());
    }

    function active() external payable {}

    function setRandoms() external onlyOwner {
        _setRandoms();
    }

    function _setRandoms() private {
        _requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function setChainLink(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        uint64 _s_subscriptionId
    ) public onlyOwner {
        _setChainLink(
            _callbackGasLimit,
            _requestConfirmations,
            _numWords,
            _s_subscriptionId
        );
    }

    function _setChainLink(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        uint64 _s_subscriptionId
    ) private {
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        numWords = _numWords;
        s_subscriptionId = _s_subscriptionId;
    }

    function setAddress(address dao, address nft) external onlyOwner {
        daoAddress = dao;
        nftAddress = nft;
    }

    function setTarget(address user, uint256 prizeLevel) external {
        targets[user] = prizeLevel;
    }

    function setPayAmount(uint256 amount) external onlyOwner {
        _payAmount = amount;
    }

    function setReturnPercent(uint256[] memory percent) external onlyOwner {
        _returnPercents = percent;
    }

    function setPrizeData(
        uint256[] memory _prizes,
        uint256[] memory _prizeCounts,
        uint256[] memory _prizeMaxCounts
    ) external onlyOwner {
        prizes = _prizes;
        prizeCounts = _prizeCounts;
        prizeMaxCounts = _prizeMaxCounts;
    }

    function getRemains() external view returns (uint256[] memory remains) {
        remains = new uint256[](prizeMaxCounts.length);
        for (uint8 i = 0; i < prizeMaxCounts.length; i++) {
            remains[i] = prizeMaxCounts[i] - prizeCounts[i];
        }
    }

    function getResult() external view returns (uint256) {
        return results[_msgSender()];
    }

    function getRandomTotal() public view returns (uint256 total) {
        for (uint8 i = 0; i < prizes.length; i++) {
            if (prizeCounts[i] < prizeMaxCounts[i]) {
                total = total.add(prizeMaxCounts[i].sub(prizeCounts[i]));
            }
        }
    }

    function getPrizeLevel(address sender, uint256 randomNumber)
        public
        view
        returns (uint256 prizeLevel, uint256 prizeIndex)
    {
        uint256 targetIndex = targets[sender];
        if (
            targetIndex > 0 &&
            prizeCounts[targetIndex] < prizeMaxCounts[targetIndex]
        ) {
            prizeIndex = targetIndex;
            prizeLevel = prizes[targetIndex];
        } else {
            uint256 randomTotal = getRandomTotal();
            if (randomTotal > 0) {
                uint256 random = randomNumber % randomTotal;
                for (uint8 i = 0; i < prizes.length; i++) {
                    if (prizeCounts[i] < prizeMaxCounts[i]) {
                        uint256 interval = prizeMaxCounts[i].sub(
                            prizeCounts[i]
                        );
                        if (random < interval) {
                            prizeIndex = i;
                            prizeLevel = prizes[i];
                            break;
                        }
                        random = random.sub(interval);
                    }
                }
            }
        }
    }

    function getNumberFromRandoms() internal returns (uint256, uint256) {
        for (uint8 i = 0; i < _randoms.length; i++) {
            if (_randoms[i] != 0) {
                uint256 random = _randoms[i];
                _randoms[i] = 0;
                return (random, i);
            }
        }
        return (0, 0);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        if (_requestId == requestId) {
            _randoms = randomWords;
            _requestId = 0;
        }
    }

    function participate() external payable nonReentrant {
        require(_requestId == 0, "Error: Random number being generated");
        require(msg.value == _payAmount, "Error: Wrong number of payments");
        address _sender = _msgSender();
        require(
            results[_sender] == 0,
            "Error: Users have already participated in the draw"
        );
        require(
            IDAO(daoAddress).getParent(_sender) != address(0),
            "Error: Must be bound to a superior to participate in"
        );
        (uint256 random, uint256 index) = getNumberFromRandoms();
        if (random > 0) {
            if (index == _randoms.length - 1) {
                _setRandoms();
            }
            _drawAndReturn(_sender, random);
        } else {
            _setRandoms();
        }
    }

    function _drawAndReturn(address _sender, uint256 random) private {
        // draw result
        require(_sender != address(0), "Error: The user cannot be address(0)");
        require(
            results[_sender] == 0,
            "Error: Users have already participated in the draw"
        );
        require(getRandomTotal() > 0, "Error: The current prize is finished");
        (uint256 prizeLevel, uint256 prizeIndex) = getPrizeLevel(
            _sender,
            random
        );
        require(prizeLevel > 0, "Error: The current prize is finished");
        prizeCounts[prizeIndex] = prizeCounts[prizeIndex].add(1);
        results[_sender] = prizeLevel;
        resultUsers.push(_sender);

        // check if the conditions for mint nft are met
        uint256 nftLevel = nftLevels[prizeLevel];
        if (nftLevel > 0) INFT(nftAddress).mint(_sender, nftLevel);

        // return percent
        address level1 = IDAO(daoAddress).getParent(_sender);
        if (level1 == address(0)) level1 = owner();
        // return to level 1
        (bool success, ) = payable(level1).call{
            value: _payAmount.mul(_returnPercents[0]).div(10000)
        }("");
        require(
            success,
            "Address: unable to send level1 value, recipient may have reverted"
        );
        address level2 = IDAO(daoAddress).getParent(level1);
        if (level2 == address(0)) level2 = owner();
        // return to level 2
        (success, ) = payable(level2).call{
            value: _payAmount.mul(_returnPercents[1]).div(10000)
        }("");
        require(
            success,
            "Address: unable to send level2 value, recipient may have reverted"
        );
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
