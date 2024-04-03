// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/NFTMarket.sol";
import "forge-std/Script.sol";

import "./BaseScript.sol";


// forge script script/Deployer.s.sol:TreasureDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
//forge script script/Deployer.s.sol:PrivacyContractsDeployer --rpc-url $MUMBAI_RPC_URL --broadcast -vvvv
//forge script script/Deployer.s.sol:PrivacyContractsDeployer --rpc-url $MUMBAI_RPC_URL --broadcast --account a2 -vvvv
contract PrivacyContractsDeployer is BaseScript {
   

    function run() external  broadcaster{
        
        // todo: write deploy script here   
    Options memory opts;
            opts.unsafeSkipAllChecks = true;
            address NFTMarketProxy = Upgrades.deployTransparentProxy(
                "NFTMarket.sol",
                deployer,
                abi.encodeCall(
                    NFTMarket.initialize,
                    (address(deployer), 1000,0)
                ),
                opts
            );
        NFTMarket nftMarket = NFTMarket(NFTMarketProxy);
        console.log("nftMarket deployed on %s", address(nftMarket));
       
    }

}