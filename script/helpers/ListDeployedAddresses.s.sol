// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import "forge-std/console.sol";
import "forge-std/Script.sol";

contract ListDeployedAddresses is Script {
    using stdJson for string;

    function run() external view {
        string memory chainId = "1337";
        string memory path =
            string.concat(vm.projectRoot(), "/broadcast/DeployLocal.s.sol/", chainId, "/run-latest.json");
        string memory deployData = vm.readFile(path);

        // overset the number because don't know how to get the exact number of deployed contracts
        uint256 numOfContracts = 30;
        for (uint256 j; j < numOfContracts; j++) {
            string memory txType = abi.decode(
                deployData.parseRaw(string.concat(".transactions[", vm.toString(j), "].transactionType")), (string)
            );

            if (keccak256(abi.encodePacked(txType)) != keccak256(abi.encodePacked("CREATE"))) {
                continue;
            }

            string memory contractName = abi.decode(
                deployData.parseRaw(string.concat(".transactions[", vm.toString(j), "].contractName")), (string)
            );
            address contractAddress = abi.decode(
                deployData.parseRaw(string.concat(".transactions[", vm.toString(j), "].contractAddress")), (address)
            );

            console.log(string(contractName));
            console.logAddress(contractAddress);
            console.log("========");
        }
    }
}
