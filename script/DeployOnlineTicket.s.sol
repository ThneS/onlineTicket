// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PlatformToken.sol";
import "../src/TicketManager.sol";
import "../src/EventManager.sol";
import "../src/TokenSwap.sol";
import "../src/Marketplace.sol";

contract DeployOnlineTicket is Script {
    PlatformToken public platformToken;
    TicketManager public ticketManager;
    EventManager public eventManager;
    TokenSwap public tokenSwap;
    Marketplace public marketplace;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== OnlineTicket Full Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PlatformToken
        console.log("\n1. Deploying PlatformToken...");
        platformToken = new PlatformToken(deployer);
        console.log("PlatformToken deployed at:", address(platformToken));

        // 2. Deploy TicketManager
        console.log("\n2. Deploying TicketManager...");
        ticketManager = new TicketManager(deployer);
        console.log("TicketManager deployed at:", address(ticketManager));

        // 3. Deploy EventManager
        console.log("\n3. Deploying EventManager...");
        eventManager = new EventManager(
            deployer,
            address(ticketManager),
            address(platformToken)
        );
        console.log("EventManager deployed at:", address(eventManager));

        // 4. Deploy TokenSwap
        console.log("\n4. Deploying TokenSwap...");
        tokenSwap = new TokenSwap(
            deployer,
            address(platformToken),
            "OnlineTicket LP",
            "OTT-LP"
        );
        console.log("TokenSwap deployed at:", address(tokenSwap));

        // 5. Deploy Marketplace
        console.log("\n5. Deploying Marketplace...");
        marketplace = new Marketplace(
            deployer,
            address(ticketManager),
            address(eventManager),
            address(platformToken)
        );
        console.log("Marketplace deployed at:", address(marketplace));

        // 6. Setup permissions
        console.log("\n6. Setting up permissions...");

        // Authorize EventManager to mint tickets
        ticketManager.setMinterAuthorization(address(eventManager), true);
        console.log("EventManager authorized as minter");

        // Authorize Marketplace to transfer tickets
        ticketManager.setMinterAuthorization(address(marketplace), true);
        console.log("Marketplace authorized as minter");

        // Authorize deployer as organizer
        eventManager.authorizeOrganizer(deployer, true);
        console.log("Deployer authorized as organizer"); // 7. Add initial liquidity
        console.log("\n7. Adding initial liquidity...");

        uint256 tokenAmount = 1000000 * 1e18; // 1M tokens
        uint256 ethAmount = 10 ether;

        // Mint tokens for liquidity
        platformToken.mint(address(this), tokenAmount);

        // Approve tokens for swap
        platformToken.approve(address(tokenSwap), tokenAmount);

        // Add liquidity
        if (address(this).balance >= ethAmount) {
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
            } catch Error(string memory reason) {
                console.log("Liquidity addition failed:", reason);
            }
        }

        // 8. Mint initial tokens for deployer
        platformToken.mint(deployer, 1000000 * 1e18);
        console.log("Minted 1M tokens for deployer");

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("PlatformToken:", address(platformToken));
        console.log("TicketManager:", address(ticketManager));
        console.log("EventManager:", address(eventManager));
        console.log("TokenSwap:", address(tokenSwap));
        console.log("Marketplace:", address(marketplace));

        console.log("\n=== Environment Variables ===");
        console.log("export PLATFORM_TOKEN_ADDRESS=", address(platformToken));
        console.log("export TICKET_MANAGER_ADDRESS=", address(ticketManager));
        console.log("export EVENT_MANAGER_ADDRESS=", address(eventManager));
        console.log("export TOKEN_SWAP_ADDRESS=", address(tokenSwap));
        console.log("export MARKETPLACE_ADDRESS=", address(marketplace));
    }
}
