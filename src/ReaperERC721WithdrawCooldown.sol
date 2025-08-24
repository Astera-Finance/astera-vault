// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.0;

import {ERC721} from "oz/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "oz/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "oz/access/Ownable.sol";

/**
 * @notice ERC721 token to track the cooldown period for each user in `ReaperVaultV2Cooldown`.
 * @dev This contract is deployed in the constructor by `ReaperVaultV2Cooldown`.
 * The `ReaperVaultV2Cooldown` contract is the owner of this contract.
 */
contract ReaperERC721WithdrawCooldown is ERC721, ERC721Enumerable, Ownable {
    /// State variables
    uint256 private _nextTokenId;
    mapping(uint256 _tokenId => WithdrawCooldownInfo) public cooldownInfo;

    /// Struct
    struct WithdrawCooldownInfo {
        uint256 mintingTimestamp;
        uint256 sharesToWithdraw;
    }

    /// Events
    event WithdrawCooldownMinted(uint256 indexed tokenId, address indexed to, uint256 sharesToWithdraw);
    event WithdrawCooldownBurned(uint256 indexed tokenId);

    constructor(address _initialOwner) ERC721("ReaperERC721WithdrawCooldown", "RWC") Ownable(_initialOwner) {}

    /**
     * @notice Mints a new withdraw cooldown NFT to the specified address
     * @dev Can only be called by the owner (ReaperVaultV2Cooldown)
     * @param _to Address that will receive the NFT
     * @param _sharesToWithdraw Amount of shares that can be withdrawn when cooldown period ends
     * @return The ID of the newly minted NFT
     */
    function safeMint(address _to, uint256 _sharesToWithdraw) public onlyOwner returns (uint256) {
        uint256 tokenId_ = _nextTokenId++;
        cooldownInfo[tokenId_] =
            WithdrawCooldownInfo({mintingTimestamp: block.timestamp, sharesToWithdraw: _sharesToWithdraw});
        _safeMint(_to, tokenId_);
        emit WithdrawCooldownMinted(tokenId_, _to, _sharesToWithdraw);
        return tokenId_;
    }

    /**
     * @notice Burns a withdraw cooldown NFT and removes its associated data
     * @dev Overrides ERC721Burnable's burn function to delete cooldown info
     * @dev Can only be called by the owner (ReaperVaultV2Cooldown)
     * @param tokenId_ The ID of the NFT to burn
     */
    function burn(uint256 tokenId_) public onlyOwner {
        delete cooldownInfo[tokenId_];
        _burn(tokenId_);
        emit WithdrawCooldownBurned(tokenId_);
    }

    /**
     * @notice Returns the cooldown info for a given token ID
     * @param tokenId_ The ID of the NFT to get the cooldown info for
     * @return The cooldown info for the given token ID
     */
    function getCooldownInfo(uint256 tokenId_) public view returns (WithdrawCooldownInfo memory) {
        return cooldownInfo[tokenId_];
    }

    /// --- The following functions are overrides required by Solidity ---
    function _update(address to_, uint256 tokenId_, address auth_)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to_, tokenId_, auth_);
    }

    function _increaseBalance(address account_, uint128 value_) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account_, value_);
    }

    function supportsInterface(bytes4 interfaceId_) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId_);
    }
}
