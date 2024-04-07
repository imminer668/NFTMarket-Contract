// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console, StdAssertions} from "forge-std/Test.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract NFTMarketTest is Test {
    address admin = makeAddr("admin");
    address user = makeAddr("user");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    NFTMarket public nftMarket;

    function setUp() public {
        //deploy the NFTMarket contract
        vm.startPrank(admin);
        {
            Options memory opts;
            opts.unsafeSkipAllChecks = true;
            address nftMarketProxy = Upgrades.deployTransparentProxy(
                "NFTMarket.sol",
                admin,
                abi.encodeCall(NFTMarket.initialize, (address(admin), 1000, 0)),
                opts
            );
            console.log("proxy~:", nftMarketProxy);
            nftMarket = NFTMarket(nftMarketProxy);
        }
        vm.stopPrank();
    }
}
