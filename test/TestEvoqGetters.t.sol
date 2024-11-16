// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestEvoqGetters is TestSetup {
    using CompoundMath for uint256;

    struct UserBalanceStates {
        uint256 collateralValue;
        uint256 debtValue;
        uint256 maxDebtValue;
        uint256 liquidationValue;
    }

    enum PositionType {
        SUPPLIERS_IN_P2P,
        SUPPLIERS_ON_POOL,
        BORROWERS_IN_P2P,
        BORROWERS_ON_POOL
    }

    function testGetHead() public {
        uint256 amount = 10_000 ether;
        uint256 toBorrow = amount / 10;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);

        assertEq(address(0), evoq.getHead(vDai, Types.PositionType.SUPPLIERS_IN_P2P));
        assertEq(address(borrower1), evoq.getHead(vDai, Types.PositionType.SUPPLIERS_ON_POOL));
        assertEq(address(0), evoq.getHead(vDai, Types.PositionType.BORROWERS_IN_P2P));
        assertEq(address(0), evoq.getHead(vDai, Types.PositionType.BORROWERS_ON_POOL));

        borrower1.borrow(vDai, toBorrow);

        assertEq(address(borrower1), evoq.getHead(vDai, Types.PositionType.SUPPLIERS_IN_P2P));
        assertEq(address(borrower1), evoq.getHead(vDai, Types.PositionType.SUPPLIERS_ON_POOL));
        assertEq(address(borrower1), evoq.getHead(vDai, Types.PositionType.BORROWERS_IN_P2P));
        assertEq(address(0), evoq.getHead(vDai, Types.PositionType.BORROWERS_ON_POOL));

        borrower1.borrow(vUsdc, (toBorrow));

        assertEq(address(borrower1), evoq.getHead(vUsdc, Types.PositionType.BORROWERS_ON_POOL));
    }

    function testGetNext() public {
        uint256 amount = 10_000 ether;
        uint256 toBorrow = amount / 10;

        uint256 maxSortedUsers = 10;
        evoq.setMaxSortedUsers(maxSortedUsers);
        createSigners(maxSortedUsers);
        for (uint256 i; i < borrowers.length; i++) {
            borrowers[i].approve(dai, amount - i * 1e18);
            borrowers[i].supply(vDai, amount - i * 1e18);
            borrowers[i].borrow(vUsdc, (toBorrow - i * 1e18));
        }

        address nextSupplyOnPool = address(borrowers[0]);
        address nextBorrowOnPool = address(borrowers[0]);

        for (uint256 i; i < borrowers.length - 1; i++) {
            nextSupplyOnPool = evoq.getNext(vDai, Types.PositionType.SUPPLIERS_ON_POOL, nextSupplyOnPool);
            nextBorrowOnPool = evoq.getNext(vUsdc, Types.PositionType.BORROWERS_ON_POOL, nextBorrowOnPool);

            assertEq(nextSupplyOnPool, address(borrowers[i + 1]));
            assertEq(nextBorrowOnPool, address(borrowers[i + 1]));
        }

        for (uint256 i; i < borrowers.length; i++) {
            borrowers[i].borrow(vDai, (amount / 100) - i * 1e18);
        }

        for (uint256 i; i < suppliers.length; i++) {
            suppliers[i].approve(usdc, (toBorrow - i * 1e18));
            suppliers[i].supply(vUsdc, (toBorrow - i * 1e18));
        }

        address nextSupplyInP2P = address(suppliers[0]);
        address nextBorrowInP2P = address(borrowers[0]);

        for (uint256 i; i < borrowers.length - 1; i++) {
            nextSupplyInP2P = evoq.getNext(vUsdc, Types.PositionType.SUPPLIERS_IN_P2P, nextSupplyInP2P);
            nextBorrowInP2P = evoq.getNext(vDai, Types.PositionType.BORROWERS_IN_P2P, nextBorrowInP2P);

            assertEq(address(suppliers[i + 1]), nextSupplyInP2P);
            assertEq(address(borrowers[i + 1]), nextBorrowInP2P);
        }
    }

    function testEnteredMarkets() public {
        borrower1.approve(dai, 10 ether);
        borrower1.supply(vDai, 10 ether);

        borrower1.approve(usdc, (10 ether));
        borrower1.supply(vUsdc, (10 ether));

        assertEq(evoq.enteredMarkets(address(borrower1), 0), vDai);
        assertEq(IEvoq(address(evoq)).enteredMarkets(address(borrower1), 0), vDai); // test the interface
        assertEq(evoq.enteredMarkets(address(borrower1), 1), vUsdc);

        // Borrower1 withdraw, USDC should be the first in enteredMarkets.
        borrower1.withdraw(vDai, type(uint256).max);

        assertEq(evoq.enteredMarkets(address(borrower1), 0), vUsdc);
    }

    function testFailUserLeftMarkets() public {
        borrower1.approve(dai, 10 ether);
        borrower1.supply(vDai, 10 ether);

        // Check that borrower1 entered Dai market.
        assertEq(evoq.enteredMarkets(address(borrower1), 0), vDai);

        // Borrower1 withdraw everything from the Dai market.
        borrower1.withdraw(vDai, 10 ether);

        // Test should fail because there is no element in the array.
        evoq.enteredMarkets(address(borrower1), 0);
    }

    function testGetAllMarkets() public {
        address[] memory marketsCreated = evoq.getAllMarkets();
        for (uint256 i; i < pools.length; i++) {
            assertEq(marketsCreated[i], pools[i]);
        }
    }
}
