// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/ShowManager.sol";
import "../src/DIDRegistry.sol";

contract ShowManagerTest is Test {
    DIDRegistry public registry;
    ShowManager public manager;

    address public admin;
    address public feeRecipient;
    address public org1;
    address public org2;

    function setUp() public {
        admin = makeAddr("admin");
        feeRecipient = makeAddr("fee");
        org1 = makeAddr("org1");
        org2 = makeAddr("org2");

        vm.prank(admin);
        registry = new DIDRegistry(admin);

        vm.prank(admin);
        manager = new ShowManager(feeRecipient, 5, address(registry));

        // 绑定并验证 org1 的 DID
        vm.prank(org1);
        bytes32 id1 = registry.registerDID("did:org1", "cid1");
        vm.prank(admin);
        registry.verifyDID(id1);
        vm.prank(org1);
        registry.bindAddressToDID(id1, org1);

        // org2 仅注册未验证
        vm.prank(org2);
        bytes32 id2 = registry.registerDID("did:org2", "cid2");
        vm.prank(org2);
        registry.bindAddressToDID(id2, org2);
    }

    function test_CreateShow_RequiresDID() public {
        vm.startPrank(org1);
        manager.createShow(
            "Concert",
            "desc",
            block.timestamp + 1,
            block.timestamp + 2 days,
            "NYC",
            100,
            0.02 ether,
            "ipfsCid"
        );
        vm.stopPrank();

        // nextShowId starts from 1, after create it becomes 2
        assertEq(manager.nextShowId(), 2);
    }

    function test_CreateShow_Revert_NoDID() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(bytes("Organizer must have a valid DID"));
        manager.createShow(
            "Concert",
            "desc",
            block.timestamp + 1,
            block.timestamp + 2 days,
            "NYC",
            100,
            0.02 ether,
            "ipfsCid"
        );
    }

    function test_UpdateShow_AdminOrOrganizer() public {
        // create by org1
        vm.prank(org1);
        manager.createShow(
            "Show1",
            "desc",
            block.timestamp + 1,
            block.timestamp + 2 days,
            "NYC",
            100,
            0.02 ether,
            "cid1"
        );

        // admin updates
        vm.prank(admin);
        manager.updateShow(1, "Show1-Updated", "uri://meta");
    }

    function test_Cancel_Activate_End_Flow() public {
        vm.prank(org1);
        manager.createShow(
            "Flow",
            "desc",
            block.timestamp + 1,
            block.timestamp + 2 days,
            "NYC",
            100,
            0.02 ether,
            "cid"
        );

        // cannot activate before start
        vm.prank(org1);
        vm.expectRevert(bytes("Too early to activate"));
        manager.activateShow(1);

        // fast forward to start
        vm.warp(block.timestamp + 2);

        vm.prank(org1);
        manager.activateShow(1);

        // cannot end before endTime
        vm.prank(org1);
        vm.expectRevert(bytes("Too early to end"));
        manager.endShow(1);

        // move to after end
        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(org1);
        manager.endShow(1);
    }

    function test_CreateShow_InputValidation() public {
        // name required
        vm.prank(org1);
        vm.expectRevert(bytes("Show name is required"));
        manager.createShow(
            "",
            "desc",
            block.timestamp + 1,
            block.timestamp + 2 days,
            "NYC",
            100,
            0.02 ether,
            "cid"
        );

        // invalid time range
        vm.prank(org1);
        vm.expectRevert(bytes("Invalid show time range"));
        manager.createShow(
            "n",
            "d",
            block.timestamp + 10,
            block.timestamp + 1,
            "NYC",
            100,
            0.02 ether,
            "cid"
        );

        // invalid tickets
        vm.prank(org1);
        vm.expectRevert(bytes("Invalid total tickets"));
        manager.createShow(
            "n",
            "d",
            block.timestamp + 1,
            block.timestamp + 2,
            "NYC",
            0,
            0.02 ether,
            "cid"
        );

        // price too low
        vm.prank(org1);
        vm.expectRevert(bytes("Ticket price too low"));
        manager.createShow(
            "n",
            "d",
            block.timestamp + 1,
            block.timestamp + 2,
            "NYC",
            10,
            0.005 ether,
            "cid"
        );
    }
}
