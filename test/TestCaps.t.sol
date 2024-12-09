pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestCaps is TestSetup {
    using CompoundMath for uint256;

    function testSupplyCap() public {
        address[] memory markets = new address[](1);
        uint256[] memory supplyCaps = new uint256[](1);
        markets[0] = vDai;
        supplyCaps[0] = 10_000 ether;
        evoq.setMarketSupplyCaps(markets, supplyCaps);

        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        testEquality(ERC20(vDai).balanceOf(address(evoq)), expectedOnPool, "balance of vToken");

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        testEquality(onPool, expectedOnPool, "on pool");
        assertEq(inP2P, 0, "in peer-to-peer");

        // try to supply more than the cap
        supplier1.approve(dai, 1 ether);

        hevm.expectRevert();
        supplier1.supply(vDai, 1 ether); // revert because exceeds the supply cap

        // borrow to make supplier1 p2p more than 0
        uint256 borrowAmount = 5_000 ether;
        borrower1.approve(usdc, borrowAmount * 2);
        borrower1.supply(vUsdc, borrowAmount * 2);
        borrower1.borrow(vDai, borrowAmount);

        (inP2P, onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        assertGe(inP2P, 0);

        hevm.expectRevert();
        supplier1.supply(vDai, 1 ether); // revert because exceeds the supply cap
    }

    function testBorrowCap() public {
        address[] memory markets = new address[](1);
        uint256[] memory borrowCaps = new uint256[](1);
        markets[0] = vUsdt;
        borrowCaps[0] = 10_000 ether;
        evoq.setMarketBorrowCaps(markets, borrowCaps);

        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, 2 * amount);
        borrower1.supply(vUsdc, 2 * amount);
        borrower1.borrow(vUsdt, amount);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        uint256 expectedOnPool = amount.div(IVToken(vUsdt).borrowIndex());

        testEquality(onPool, expectedOnPool);
        assertEq(inP2P, 0);

        // try to borrow more than the cap
        hevm.expectRevert();
        borrower1.borrow(vUsdt, 1 ether);

        // supply to make borrower1 p2p more than 0
        supplier1.approve(usdt, amount);
        supplier1.supply(vUsdt, amount);

        (inP2P, onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));
        assertGe(inP2P, 0);

        hevm.expectRevert();
        borrower1.borrow(vUsdt, 1 ether); // revert because exceeds the borrow cap
    }
}
