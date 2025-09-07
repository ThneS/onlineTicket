// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PlatformToken.sol";
import "../src/TicketManager.sol";
import "../src/EventManager.sol";
import "../src/TokenSwap.sol";
import "../src/Marketplace.sol";
import "../src/ShowManager.sol";
import "../src/DIDRegistry.sol";

contract QuickDeploy is Script {
    PlatformToken public platformToken;
    TicketManager public ticketManager;
    EventManager public eventManager;
    TokenSwap public tokenSwap;
    Marketplace public marketplace;
    DIDRegistry public didRegistry;
    ShowManager public showManager;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Quick Deploy OnlineTicket ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PlatformToken
        console.log("\n1. Deploying PlatformToken...");
        platformToken = new PlatformToken(deployer);
        console.log("PlatformToken:", address(platformToken));

        // 2. Deploy TicketManager
        console.log("\n2. Deploying TicketManager...");
        ticketManager = new TicketManager(deployer);
        console.log("TicketManager:", address(ticketManager));

        // 3. Deploy EventManager
        console.log("\n3. Deploying EventManager...");
        eventManager = new EventManager(
            deployer,
            address(ticketManager),
            address(platformToken)
        );
        console.log("EventManager:", address(eventManager));

        // 4. Deploy TokenSwap
        console.log("\n4. Deploying TokenSwap...");
        tokenSwap = new TokenSwap(
            deployer,
            address(platformToken),
            "OnlineTicket LP",
            "OTT-LP"
        );
        console.log("TokenSwap:", address(tokenSwap));

        // 5. Deploy Marketplace
        console.log("\n5. Deploying Marketplace...");
        marketplace = new Marketplace(
            deployer,
            address(ticketManager),
            address(eventManager),
            address(platformToken)
        );
        console.log("Marketplace:", address(marketplace));

        // 6. Deploy DIDRegistry
        console.log("\n6. Deploying DIDRegistry...");
        didRegistry = new DIDRegistry(deployer);
        console.log("DIDRegistry:", address(didRegistry));

        // Bootstrap a demo DID for deployer (bind + verify) so organizer can create shows immediately
        console.log("Bootstrapping demo DID for deployer...");
        bytes32 demoDid = didRegistry.registerDIDFor(
            "did:example:deployer",
            "ipfs://deployer",
            deployer
        );
        didRegistry.bindAddressToDID(demoDid, deployer);
        didRegistry.verifyDID(demoDid);

        // 7. Deploy ShowManager (feeRecipient = deployer, platformFee = 5%)
        console.log("\n7. Deploying ShowManager...");
        showManager = new ShowManager(deployer, 5, address(didRegistry));
        console.log("ShowManager:", address(showManager));

        // 8. Setup permissions
        console.log("\n8. Setting up permissions...");

        // Authorize EventManager to mint tickets
        ticketManager.setMinterAuthorization(address(eventManager), true);
        console.log("EventManager authorized as minter");

        // Authorize Marketplace to transfer tickets
        ticketManager.setMinterAuthorization(address(marketplace), true);
        console.log("Marketplace authorized as minter");

        // Authorize deployer as organizer
        eventManager.authorizeOrganizer(deployer, true);
        console.log("Deployer authorized as organizer");

        // 9. Optional: Add initial liquidity
        if (deployer.balance >= 1 ether) {
            console.log("\n9. Adding initial liquidity...");

            uint256 tokenAmount = 100000 * 1e18; // 100,000 tokens
            uint256 ethAmount = 1 ether;

            // Mint tokens for liquidity to deployer
            platformToken.mint(deployer, tokenAmount);

            // Approve tokens for swap (deployer needs to approve)
            platformToken.approve(address(tokenSwap), tokenAmount);

            // Add liquidity
            try
                tokenSwap.addLiquidity{value: ethAmount}(
                    tokenAmount,
                    tokenAmount,
                    ethAmount
                )
            {
                console.log("Initial liquidity added successfully");
                console.log("- Tokens:", tokenAmount / 1e18);
                console.log("- ETH:", ethAmount / 1e18);
            } catch {
                console.log("Liquidity addition failed, skipped");
            }
        }
        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("PlatformToken:", address(platformToken));
        console.log("TicketManager:", address(ticketManager));
        console.log("EventManager:", address(eventManager));
        console.log("TokenSwap:", address(tokenSwap));
        console.log("Marketplace:", address(marketplace));
        console.log("DIDRegistry:", address(didRegistry));
        console.log("ShowManager:", address(showManager));
        console.log("=== Deployment Complete ===");

        // Save addresses to environment file
        console.log("\nRun these commands to set environment variables:");
        console.log("export PLATFORM_TOKEN_ADDRESS=", address(platformToken));
        console.log("export TICKET_MANAGER_ADDRESS=", address(ticketManager));
        console.log("export EVENT_MANAGER_ADDRESS=", address(eventManager));
        console.log("export TOKEN_SWAP_ADDRESS=", address(tokenSwap));
        console.log("export MARKETPLACE_ADDRESS=", address(marketplace));
        console.log("export DID_REGISTRY_ADDRESS=", address(didRegistry));
        console.log("export SHOW_MANAGER_ADDRESS=", address(showManager));
    }
}
