// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/DIDRegistry.sol";

contract DIDRegistryTest is Test {
    DIDRegistry public registry;
    address public admin;
    address public user1;
    address public user2;
    address public other;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        other = makeAddr("other");

        vm.prank(admin);
        registry = new DIDRegistry(admin);
    }

    function _registerAs(
        address who,
        string memory did,
        string memory cid
    ) internal returns (bytes32) {
        vm.prank(who);
        return registry.registerDID(did, cid);
    }

    function test_RegisterDID_SetsFields() public {
        string memory did = "did:ethr:0xabc";
        string memory cid = "bafy...cid";

        vm.expectEmit(true, false, true, true);
        emit DIDRegistry.DIDRegistered(keccak256(bytes(did)), did, user1, cid);

        bytes32 id = _registerAs(user1, did, cid);

        (
            address controller,
            string memory rDid,
            string memory rCid,
            bool verified,
            bool revoked,
            uint256 createdAt,
            uint256 updatedAt
        ) = registry.getDID(id);

        assertEq(controller, user1);
        assertEq(rDid, did);
        assertEq(rCid, cid);
        assertFalse(verified);
        assertFalse(revoked);
        assertGt(createdAt, 0);
        assertEq(createdAt, updatedAt);
    }

    function test_RegisterDID_Empty_Reverts() public {
        vm.prank(user1);
        vm.expectRevert(bytes("DID: empty"));
        registry.registerDID("", "cid");
    }

    function test_RegisterDID_Duplicate_Reverts() public {
        string memory did = "did:ethr:0xabc";
        _registerAs(user1, did, "cid1");

        vm.prank(user2);
        vm.expectRevert(bytes("DID: already exists"));
        registry.registerDID(did, "cid2");
    }

    function test_RegisterDIDFor_OnlyAdmin() public {
        // non-admin cannot call
        vm.prank(user1);
        vm.expectRevert();
        registry.registerDIDFor("did:x", "cid", user1);

        // admin can call, and sets controller to target
        vm.prank(admin);
        bytes32 id = registry.registerDIDFor("did:org", "cidOrg", user1);
        (address controller, , , , , , ) = registry.getDID(id);
        assertEq(controller, user1);
    }

    function test_UpdateCID_OnlyController() public {
        bytes32 id = _registerAs(user1, "did:u1", "cid1");

        // not controller
        vm.prank(user2);
        vm.expectRevert(bytes("DID: not controller"));
        registry.updateCID(id, "cid2");

        // controller updates
        vm.prank(user1);
        registry.updateCID(id, "cid2");
        (, , string memory cid, , , , ) = registry.getDID(id);
        assertEq(cid, "cid2");
    }

    function test_VerifyDID_OnlyVerifier() public {
        bytes32 id = _registerAs(user1, "did:u1", "cid1");

        // non-verifier
        vm.prank(user2);
        vm.expectRevert();
        registry.verifyDID(id);

        // admin has VERIFIER_ROLE by default
        vm.prank(admin);
        registry.verifyDID(id);
        assertTrue(registry.isVerified(id));
    }

    function test_RevokeDID_ByControllerOrAdmin() public {
        bytes32 id = _registerAs(user1, "did:u1", "cid1");

        // other cannot revoke
        vm.prank(other);
        vm.expectRevert(bytes("DID: not authorized"));
        registry.revokeDID(id);

        // controller can revoke
        vm.prank(user1);
        registry.revokeDID(id);
        assertFalse(registry.isVerified(id));

        // admin can also revoke (on a fresh one)
        bytes32 id2 = _registerAs(user2, "did:u2", "cid2");
        vm.prank(admin);
        registry.revokeDID(id2);
        assertFalse(registry.isVerified(id2));
    }

    function test_TransferController_OnlyController() public {
        bytes32 id = _registerAs(user1, "did:u1", "cid1");

        // not controller
        vm.prank(user2);
        vm.expectRevert(bytes("DID: not controller"));
        registry.transferController(id, user2);

        // controller transfers
        vm.prank(user1);
        registry.transferController(id, user2);
        (address controller, , , , , , ) = registry.getDID(id);
        assertEq(controller, user2);
    }

    function test_BindAndUnbind_Address() public {
        bytes32 id = _registerAs(user1, "did:u1", "cid1");

        // only controller or admin
        vm.prank(other);
        vm.expectRevert(bytes("DID: not authorized"));
        registry.bindAddressToDID(id, user1);

        // controller binds self
        vm.prank(user1);
        registry.bindAddressToDID(id, user1);
        assertEq(registry.resolveDIDByAddress(user1), id);

        // unbind by controller
        vm.prank(user1);
        registry.unbindAddress(id, user1);
        assertEq(registry.resolveDIDByAddress(user1), bytes32(0));
    }

    function test_AdminDeleteDID() public {
        bytes32 id = _registerAs(user1, "did:u1", "cid1");

        // only admin
        vm.prank(user1);
        vm.expectRevert();
        registry.adminDeleteDID(id);

        vm.prank(admin);
        registry.adminDeleteDID(id);

        // now not exist
        vm.expectRevert(bytes("DID: not exist"));
        registry.getDID(id);
    }
}
