// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../Interface/INFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract FGODAO is Initializable, Ownable {
    uint256 private _levels;
    address[] private _genesis;

    mapping(address => address) private _relations;
    mapping(address => address[]) private _childrens;

    address public nftAddress;

    function initialize() public initializer {
        _levels = 10;
        _transferOwnership(_msgSender());
    }

    function setNftAddress(address nft) external onlyOwner {
        nftAddress = nft;
    }

    function setGenesis(address[] memory genesis) external onlyOwner {
        _genesis = genesis;
    }

    function setLevels(uint256 levels) external onlyOwner {
        _levels = levels;
    }

    function getParent(address user) public view returns (address) {
        return _relations[user];
    }

    function getChildren(address user)
        external
        view
        returns (address[] memory)
    {
        return _childrens[user];
    }

    function getChildrenCount(address user) external view returns (uint256) {
        return _childrens[user].length;
    }

    function getChildrenByIndex(address user, uint256 index)
        external
        view
        returns (address)
    {
        return _childrens[user][index];
    }

    function getRelations(address user)
        external
        view
        returns (address[] memory)
    {
        address current = user;
        address[] memory relations = new address[](_levels);
        for (uint256 i = 0; i < _levels; i++) {
            current = getParent(current);
            if (current != address(0)) {
                relations[i] = current;
            } else if (_genesis.length > i) {
                relations[i] = _genesis[i];
            } else {
                relations[i] = owner();
            }
        }
        return relations;
    }

    function bind(address parent) public {
        require(
            parent != address(0),
            "Error: Superiors cannot be bound to address(0)"
        );
        address _sender = _msgSender();
        require(
            _relations[_sender] == address(0),
            "Error: The current user is already bound to a superior"
        );
        require(
            _relations[parent] != _sender && parent != _sender,
            "Error: Cannot be cycled for binding"
        );
        _relations[_sender] = parent;
        _childrens[parent].push(_sender);

        // check if the conditions for mint nft are met
        address _tmpUser = _sender;
        for (uint8 i = 0; i < _levels; i++) {
            _tmpUser = _relations[_tmpUser];
            if (_tmpUser == address(0)) return;
        }
        INFT(nftAddress).mintByInvite(_tmpUser);
    }
}
