// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestMarketStrategy is TestSetup {
    function testShouldPutBorrowerOnPool() public {
        uint256 amount = 10000 ether;
        uint256 toBorrow = 500 ether;

        evoq.setIsP2PDisabled(vDai, true);

        borrower1.approve(usdc, (amount));
        borrower1.supply(vUsdc, (amount));

        borrower1.borrow(vDai, toBorrow);

        supplier1.approve(dai, toBorrow);
        supplier1.supply(vDai, toBorrow);

        // supplier1 and borrower1 should not be in peer-to-peer
        (uint256 borrowInP2P, uint256 borrowOnPool) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        (uint256 supplyInP2P, uint256 supplyOnPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        assertEq(borrowInP2P, 0);
        assertEq(supplyInP2P, 0);
        assertGt(borrowOnPool, 0);
        assertGt(supplyOnPool, 0);
    }

    function testShouldPutSupplierOnPool() public {
        uint256 amount = 10000 ether;
        uint256 toBorrow = 500 ether;

        evoq.setIsP2PDisabled(vDai, true);

        supplier1.approve(dai, toBorrow);
        supplier1.supply(vDai, toBorrow);

        borrower1.approve(usdc, (amount));
        borrower1.supply(vUsdc, (amount));

        borrower1.borrow(vDai, toBorrow);

        // supplier1 and borrower1 should not be in peer-to-peer
        (uint256 borrowInP2P, uint256 borrowOnPool) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        (uint256 supplyInP2P, uint256 supplyOnPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        assertEq(borrowInP2P, 0);
        assertEq(supplyInP2P, 0);
        assertGt(borrowOnPool, 0);
        assertGt(supplyOnPool, 0);
    }

    function testShouldPutBorrowersOnPool() public {
        uint256 amount = 10000 ether;
        uint256 toBorrow = 100 ether;

        evoq.setIsP2PDisabled(vDai, true);

        for (uint256 i = 0; i < 3; i++) {
            borrowers[i].approve(usdc, (amount));
            borrowers[i].supply(vUsdc, (amount));
            borrowers[i].borrow(vDai, toBorrow);
        }

        supplier1.approve(dai, toBorrow);
        supplier1.supply(vDai, toBorrow);

        uint256 borrowInP2P;
        uint256 borrowOnPool;

        for (uint256 i = 0; i < 3; i++) {
            (borrowInP2P, borrowOnPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            assertEq(borrowInP2P, 0);
            assertGt(borrowOnPool, 0);
        }

        (uint256 supplyInP2P, uint256 supplyOnPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        assertEq(supplyInP2P, 0);
        assertGt(supplyOnPool, 0);
    }

    function testShouldPutSuppliersOnPool() public {
        uint256 amount = 10000 ether;
        uint256 toBorrow = 400 ether;
        uint256 toSupply = 100 ether;

        evoq.setIsP2PDisabled(vDai, true);

        for (uint256 i = 0; i < 3; i++) {
            suppliers[i].approve(dai, toSupply);
            suppliers[i].supply(vDai, toSupply);
        }

        borrower1.approve(usdc, (amount));
        borrower1.supply(vUsdc, (amount));

        borrower1.borrow(vDai, toBorrow);

        uint256 supplyInP2P;
        uint256 supplyOnPool;

        for (uint256 i = 0; i < 3; i++) {
            (supplyInP2P, supplyOnPool) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));
            assertEq(supplyInP2P, 0);
            assertGt(supplyOnPool, 0);
        }

        (uint256 borrowInP2P, uint256 borrowOnPool) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        assertEq(borrowInP2P, 0);
        assertGt(borrowOnPool, 0);
    }
}
