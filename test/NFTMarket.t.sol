// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console, StdAssertions} from "forge-std/Test.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {NftTokenManager} from "../src/NftTokenManager.sol";
import {UsdtToken} from "../src/UsdtToken.sol";

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract NFTMarketTest is Test {
    address admin = makeAddr("admin");
    address merchant = makeAddr("merchant");
    address user = makeAddr("user");
    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");

    NFTMarket public nftMarket;
    NftTokenManager public nftTokenManager;
    UsdtToken public usdt;

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

            nftTokenManager = new NftTokenManager(
                10000,
                0xf2871ee0c8b5f914ce57858eb217665feeba93b506630c144ec48ff4c5f868eb
            );
            nftTokenManager.setAllowlistMint(true);
            nftTokenManager.grantRole(MINTER_ROLE, user);
            usdt = new UsdtToken(admin);
            usdt.mint(user, 10000e6);
            usdt.mint(merchant, 10000e6);
        }
        vm.stopPrank();
    }

    /*
    admin: 0xaA10a84CE7d9AE517a52c6d5cA153b369Af99ecF
    merchant: 0x00655EA989254C13e93C5a1F74C4636b5B9926B5
    user: 0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D

Tree
└─ f2871ee0c8b5f914ce57858eb217665feeba93b506630c144ec48ff4c5f868eb
   ├─ ccada90fd39a363d6d9b9e9ee57c0dfd6a65744c7bfc51d7f4247bfb707133a9
   │  ├─ 6de91cef5c39e08c7e70bec1a69357434e1f36389b3410a03c9920a277c405dc
   │  └─ 50c68cbdd99a024fff6479c58a8ae0550c28970e3b6bfeed040bd5034047cc54
   └─ 05b26225916a54a9f7c16388731c332005e6b2f7a59dd996ab3cc9faa8357557
      └─ 05b26225916a54a9f7c16388731c332005e6b2f7a59dd996ab3cc9faa8357557

   
    #0 - 0x6de91cef5c39e08c7e70bec1a69357434e1f36389b3410a03c9920a277c405dc
    Proof
    [
    "0x50c68cbdd99a024fff6479c58a8ae0550c28970e3b6bfeed040bd5034047cc54",
    "0x05b26225916a54a9f7c16388731c332005e6b2f7a59dd996ab3cc9faa8357557"
    ]
    */
    function test_First() public {
        console.log("admin:", address(admin));
        console.log("merchant:", address(merchant));
        console.log("user:", address(user));
    }

    function test_AllowlistMint() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = (
            0x50c68cbdd99a024fff6479c58a8ae0550c28970e3b6bfeed040bd5034047cc54
        );
        proof[1] = (
            0x05b26225916a54a9f7c16388731c332005e6b2f7a59dd996ab3cc9faa8357557
        );
        vm.startPrank(admin);
        {
            //console.log("admin:", address(admin));
            nftTokenManager.allowlistMint(proof);
        }
        vm.stopPrank();
        console.log(
            "balanceOf admin:",
            nftTokenManager.balanceOf(address(admin))
        );
    }

    function test_BatchMintRemainingTokens() public {
        vm.startPrank(user);
        {
            nftTokenManager.batchMintRemainingTokens(user, 10);
            //all nft approve to nftMarket
            //nftTokenManager.setApprovalForAll(address(nftMarket), true);
            nftTokenManager.approve(address(nftMarket), 1);
        }
        vm.stopPrank();
    }

    function test_Mint() public {
        vm.startPrank(user);
        {
            //nftTokenManager._mint(admin, 1);
        }
        vm.stopPrank();
    }

    function test_ListItem() public {
        test_BatchMintRemainingTokens();
        vm.startPrank(user);
        {
            //category:1 Art,2 Collectibles,3 Music,4 Photography,5 Video,6 Utility,7 Sports,8 Virtual World
            nftMarket.listItem(
                address(nftTokenManager),
                1,
                1000e18,
                address(nftTokenManager),
                11,
                1
            );
        }

        vm.stopPrank();
    }

    function test_CancelListing() public {
        test_BatchMintRemainingTokens();
        vm.startPrank(user);
        {
            nftMarket.cancelListing(address(nftTokenManager), 1);
        }

        vm.stopPrank();
    }

    function test_UpdateListing() public {
        vm.startPrank(user);
        {
            //category:1 Art,2 Collectibles,3 Music,4 Photography,5 Video,6 Utility,7 Sports,8 Virtual World
            nftMarket.updateListing(
                address(nftTokenManager),
                1,
                1000e18,
                address(nftTokenManager),
                11,
                1
            );
        }

        vm.stopPrank();
    }

    function test_BuyItem() public {
        test_BatchMintRemainingTokens();
        vm.startPrank(user);
        {
            nftMarket.buyItem(address(nftTokenManager), 1);
        }
        vm.stopPrank();
    }

    function test_WithdrawProceeds() public {
        test_BatchMintRemainingTokens();
        test_BuyItem();
        vm.startPrank(admin);
        {
            nftMarket.withdrawProceeds();
        }
        vm.stopPrank();
    }

    function test_SetFee() public {
        vm.startPrank(admin);
        {
            nftMarket.setFee(1000);
        }
        vm.stopPrank();
    }

    function testFuzz_SetFee(uint256 amount) public {
        vm.assume(amount > 0 && amount < 10000);
        vm.startPrank(admin);
        {
            nftMarket.setFee(amount);
        }
        vm.stopPrank();
    }

     function test_getBalance() public view {
            nftMarket.getBalance();
    }
}
