// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {VaultBaseTest} from "./VaultBase.t.sol";
import {ReaperERC721WithdrawCooldown} from "../../../src/ReaperERC721WithdrawCooldown.sol";

contract VaultCooldownTest is VaultBaseTest {
    function testGivenDepositWhenInitiateWithdrawThenMintsNftAndTransfersShares() public {
        uint256 depositAmount = 100e18;
        address user = makeAddr("user1");

        deal(address(assetMock), user, depositAmount);

        vm.startPrank(user);
        assetMock.approve(address(sut), depositAmount);
        sut.deposit(depositAmount);

        uint256 userSharesBefore = sut.balanceOf(user);
        address nftAddr = address(sut.withdrawCooldownNft());
        uint256 nftSharesBefore = sut.balanceOf(nftAddr);

        sut.initiateWithdraw(40e18);

        // Shares moved from user to the NFT contract
        assertEq(sut.balanceOf(user), userSharesBefore - 40e18);
        assertEq(sut.balanceOf(nftAddr), nftSharesBefore + 40e18);

        // NFT minted with correct metadata
        ReaperERC721WithdrawCooldown nft = sut.withdrawCooldownNft();
        assertEq(nft.balanceOf(user), 1);
        uint256 tokenId = nft.tokenOfOwnerByIndex(user, 0);
        ReaperERC721WithdrawCooldown.WithdrawCooldownInfo memory info = nft.getCooldownInfo(tokenId);
        assertEq(info.sharesToWithdraw, 40e18);
        assertEq(info.mintingTimestamp, block.timestamp);

        vm.stopPrank();
    }

    function testGivenNftBeforeCooldownWhenWithdrawThenReverts() public {
        uint256 depositAmount = 50e18;
        address user = makeAddr("user2");

        deal(address(assetMock), user, depositAmount);

        vm.startPrank(user);
        assetMock.approve(address(sut), depositAmount);
        sut.deposit(depositAmount);
        sut.initiateWithdraw(20e18);

        ReaperERC721WithdrawCooldown nft = sut.withdrawCooldownNft();
        uint256 tokenId = nft.tokenOfOwnerByIndex(user, 0);

        vm.expectRevert(bytes("Cooldown period not ended"));
        sut.withdraw(tokenId);

        vm.stopPrank();
    }

    function testGivenNftAfterCooldownWhenWithdrawThenBurnsNftAndReturnsAssets() public {
        uint256 depositAmount = 120e18;
        address user = makeAddr("user3");

        deal(address(assetMock), user, depositAmount);

        vm.startPrank(user);
        assetMock.approve(address(sut), depositAmount);
        sut.deposit(depositAmount);
        sut.initiateWithdraw(70e18);

        ReaperERC721WithdrawCooldown nft = sut.withdrawCooldownNft();
        uint256 tokenId = nft.tokenOfOwnerByIndex(user, 0);

        // Wait out the cooldown
        skip(sut.cooldownPeriod() + 1);

        uint256 userAssetBefore = assetMock.balanceOf(user);
        address nftAddr = address(nft);
        uint256 nftSharesBefore = sut.balanceOf(nftAddr);

        assertEq(sut.balanceOf(nftAddr), 70e18);

        sut.withdraw(tokenId);

        // NFT burned and cooldown info cleared
        assertEq(nft.balanceOf(user), 0);
        ReaperERC721WithdrawCooldown.WithdrawCooldownInfo memory cleared = nft.getCooldownInfo(tokenId);
        assertEq(cleared.sharesToWithdraw, 0);
        assertEq(cleared.mintingTimestamp, 0);

        // Shares burned from NFT holder
        assertEq(sut.balanceOf(nftAddr), 0);

        // Assets transferred back to user at 1:1 (no profit/loss path)
        uint256 userAssetAfter = assetMock.balanceOf(user);
        assertEq(userAssetAfter - userAssetBefore, 70e18);

        vm.stopPrank();
    }

    function testGivenZeroSharesWhenInitiateWithdrawThenReverts() public {
        address user = makeAddr("user4");
        deal(address(assetMock), user, 1e18);

        vm.startPrank(user);
        assetMock.approve(address(sut), 1e18);
        sut.deposit(1e18);

        vm.expectRevert(bytes("Invalid amount"));
        sut.initiateWithdraw(0);

        vm.stopPrank();
    }

    function testGivenNonOwnerWhenWithdrawThenReverts() public {
        uint256 depositAmount = 30e18;
        address user = makeAddr("user5");
        address attacker = makeAddr("attacker");

        deal(address(assetMock), user, depositAmount);

        vm.startPrank(user);
        assetMock.approve(address(sut), depositAmount);
        sut.deposit(depositAmount);
        sut.initiateWithdraw(10e18);
        ReaperERC721WithdrawCooldown nft = sut.withdrawCooldownNft();
        uint256 tokenId = nft.tokenOfOwnerByIndex(user, 0);

        vm.stopPrank();

        vm.startPrank(attacker);
        vm.expectRevert(bytes("Not owner of token"));
        sut.withdraw(tokenId);
        vm.stopPrank();
    }

    function testGivenSingleTokenWhenWithdrawAllThenWithdrawsAndBurns() public {
        uint256 depositAmount = 80e18;
        address user = makeAddr("user6");

        deal(address(assetMock), user, depositAmount);

        vm.startPrank(user);
        assetMock.approve(address(sut), depositAmount);
        sut.deposit(depositAmount);

        // Create a single cooldown token
        sut.initiateWithdraw(50e18);

        ReaperERC721WithdrawCooldown nft = sut.withdrawCooldownNft();
        assertEq(nft.balanceOf(user), 1);

        skip(sut.cooldownPeriod() + 1);

        uint256 userAssetBefore = assetMock.balanceOf(user);
        address nftAddr = address(nft);
        uint256 nftSharesBefore = sut.balanceOf(nftAddr);

        sut.withdrawAll();

        // NFT burned and shares removed from NFT holder
        assertEq(nft.balanceOf(user), 0);
        assertEq(sut.balanceOf(nftAddr), nftSharesBefore - 50e18);

        // Underlying returned
        uint256 userAssetAfter = assetMock.balanceOf(user);
        assertEq(userAssetAfter - userAssetBefore, 50e18);

        vm.stopPrank();
    }

    function testGivenMultipleTokensWhenWithdrawAllThenWithdrawsAndBurns() public {
        uint256 depositAmount = 100e18;
        address user = makeAddr("user6");

        deal(address(assetMock), user, depositAmount);

        vm.startPrank(user);
        assetMock.approve(address(sut), depositAmount);
        sut.deposit(depositAmount);

        // Create multiple cooldown tokens
        sut.initiateWithdraw(50e18);

        // assert nft contract has 50e18 shares and user has 50e18 shares
        assertEq(sut.balanceOf(address(sut.withdrawCooldownNft())), 50e18);
        assertEq(sut.balanceOf(user), 50e18);

        sut.initiateWithdraw(30e18);

        // assert nft contract has 80e18 shares and user has 20e18 shares
        assertEq(sut.balanceOf(address(sut.withdrawCooldownNft())), 80e18);
        assertEq(sut.balanceOf(user), 20e18);

        ReaperERC721WithdrawCooldown nft = sut.withdrawCooldownNft();
        assertEq(nft.balanceOf(user), 2);

        skip(sut.cooldownPeriod() + 1);

        uint256 userAssetBefore = assetMock.balanceOf(user);
        address nftAddr = address(nft);
        uint256 nftSharesBefore = sut.balanceOf(nftAddr);

        sut.withdrawAll();

        // NFT burned and shares removed from NFT holder
        assertEq(nft.balanceOf(user), 0);
        assertEq(sut.balanceOf(nftAddr), nftSharesBefore - 80e18);
        assertEq(assetMock.balanceOf(nftAddr), 0);

        // Underlying returned
        uint256 userAssetAfter = assetMock.balanceOf(user);
        assertEq(userAssetAfter - userAssetBefore, 80e18);

        vm.stopPrank();
    }

    function testUpdateCooldownPeriodAccessAndEffect() public {
        uint256 initial = sut.cooldownPeriod();

        // Unauthorized roles should revert
        vm.startPrank(STRATEGIST.addr);
        vm.expectRevert(bytes("Unauthorized access"));
        sut.updateCooldownPeriod(2 days);
        vm.stopPrank();

        vm.startPrank(GUARDIAN.addr);
        vm.expectRevert(bytes("Unauthorized access"));
        sut.updateCooldownPeriod(2 days);
        vm.stopPrank();

        // Authorized: ADMIN can update
        vm.startPrank(ADMIN.addr);
        sut.updateCooldownPeriod(2 days);
        vm.stopPrank();
        assertEq(sut.cooldownPeriod(), 2 days);

        // Authorized: DEFAULT_ADMIN can also update
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.updateCooldownPeriod(3 days);
        vm.stopPrank();
        assertEq(sut.cooldownPeriod(), 3 days);

        // Ensure it actually changed from initial
        assertTrue(sut.cooldownPeriod() != initial);
    }

    function testGetUserWithdrawCooldownInfoReturnsCorrectDataBeforeCooldown() public {
        uint256 depositAmount = 100e18;
        address user = makeAddr("infoUser");

        deal(address(assetMock), user, depositAmount);

        vm.startPrank(user);
        assetMock.approve(address(sut), depositAmount);
        sut.deposit(depositAmount);

        // Create two cooldown NFTs
        sut.initiateWithdraw(40e18);
        sut.initiateWithdraw(10e18);

        ReaperERC721WithdrawCooldown nft = sut.withdrawCooldownNft();
        assertEq(nft.balanceOf(user), 2);

        (
            uint256 nbTokens,
            uint256 amountWithdrawable,
            uint256[] memory tokenIds,
            uint256[] memory sharesToWithdraw,
            uint256[] memory timeLeftBeforeWithdraw
        ) = sut.getUserWithdrawCooldownInfo(user);

        assertEq(nbTokens, 2);
        assertEq(amountWithdrawable, 0);
        assertEq(tokenIds.length, 2);
        assertEq(sharesToWithdraw.length, 2);
        assertEq(timeLeftBeforeWithdraw.length, 2);

        uint256 id0 = nft.tokenOfOwnerByIndex(user, 0);
        uint256 id1 = nft.tokenOfOwnerByIndex(user, 1);
        assertEq(tokenIds[0], id0);
        assertEq(tokenIds[1], id1);

        // Shares match the amounts initiated in order
        assertEq(sharesToWithdraw[0], 40e18);
        assertEq(sharesToWithdraw[1], 10e18);

        // Time left should be > 0 and <= cooldownPeriod at mint time
        assertEq(timeLeftBeforeWithdraw[0], sut.cooldownPeriod());
        assertEq(timeLeftBeforeWithdraw[1], sut.cooldownPeriod());

        skip(100);
        (nbTokens, amountWithdrawable, tokenIds, sharesToWithdraw, timeLeftBeforeWithdraw) =
            sut.getUserWithdrawCooldownInfo(user);

        assertEq(nbTokens, 2);
        assertEq(amountWithdrawable, 0);
        assertEq(tokenIds.length, 2);
        assertEq(sharesToWithdraw.length, 2);
        assertEq(timeLeftBeforeWithdraw.length, 2);
        assertEq(sharesToWithdraw[0], 40e18);
        assertEq(sharesToWithdraw[1], 10e18);
        assertEq(timeLeftBeforeWithdraw[0], sut.cooldownPeriod() - 100);
        assertEq(timeLeftBeforeWithdraw[1], sut.cooldownPeriod() - 100);

        skip(sut.cooldownPeriod());
        (nbTokens, amountWithdrawable, tokenIds, sharesToWithdraw, timeLeftBeforeWithdraw) =
            sut.getUserWithdrawCooldownInfo(user);

        assertEq(nbTokens, 2);
        assertEq(amountWithdrawable, 50e18);
        assertEq(tokenIds.length, 2);
        assertEq(sharesToWithdraw.length, 2);
        assertEq(timeLeftBeforeWithdraw.length, 2);
        assertEq(sharesToWithdraw[0], 40e18);
        assertEq(sharesToWithdraw[1], 10e18);
        assertEq(timeLeftBeforeWithdraw[0], 0);
        assertEq(timeLeftBeforeWithdraw[1], 0);

        sut.withdraw(tokenIds[0]);

        (nbTokens, amountWithdrawable, tokenIds, sharesToWithdraw, timeLeftBeforeWithdraw) =
            sut.getUserWithdrawCooldownInfo(user);

        assertEq(nbTokens, 1);
        assertEq(amountWithdrawable, 10e18);
        assertEq(tokenIds.length, 1);
        assertEq(sharesToWithdraw.length, 1);
        assertEq(timeLeftBeforeWithdraw.length, 1);
        assertEq(sharesToWithdraw[0], 10e18);
        assertEq(timeLeftBeforeWithdraw[0], 0);

        sut.withdrawAll();

        (nbTokens, amountWithdrawable, tokenIds, sharesToWithdraw, timeLeftBeforeWithdraw) =
            sut.getUserWithdrawCooldownInfo(user);

        assertEq(nbTokens, 0);
        assertEq(amountWithdrawable, 0);

        assertEq(tokenIds.length, 0);
        assertEq(sharesToWithdraw.length, 0);
        assertEq(timeLeftBeforeWithdraw.length, 0);

        vm.stopPrank();
    }
}
