// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IWBNBGateway {
    function WBNB() external view returns (address);
    function VBNB() external view returns (address);
    function EVOQ() external view returns (address);
    function EVOQ_TREASURY() external view returns (address);

    function skim(address erc20) external;

    function supplyBNB(address onBehalf) external payable returns (uint256 supplied);
    function borrowBNB(uint256 amount, address receiver) external returns (uint256 borrowed);
    function repayBNB(address onBehalf) external payable returns (uint256 repaid);
    function withdrawBNB(uint256 amount, address receiver) external returns (uint256 withdrawn);
}
