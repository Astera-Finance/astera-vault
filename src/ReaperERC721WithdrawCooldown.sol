// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.0;

import {ERC721} from "oz/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "oz/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "oz/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "oz/access/Ownable.sol";

/**
 * @notice ERC721 token to track the cooldown period for each user in `ReaperVaultV2Cooldown`.
 * @dev This contract is deployed in the constructor by `ReaperVaultV2Cooldown`.
 * The `ReaperVaultV2Cooldown` contract is the owner of this contract.
 */
contract ReaperERC721WithdrawCooldown is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;

    constructor(address initialOwner) ERC721("ReaperERC721WithdrawCooldown", "RWC") Ownable(initialOwner) {}

    function safeMint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function burn(uint256 tokenId) public override onlyOwner {
        super.burn(tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
