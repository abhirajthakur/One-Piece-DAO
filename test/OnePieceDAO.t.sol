// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {OnePieceDAO} from "../src/OnePieceDAO.sol";
import {Box} from "../src/Box.sol";
import {Timelock} from "../src/Timelock.sol";
import {DevilFruitToken} from "../src/GovernanceToken.sol";

contract OnePieceDAOTest is Test {
    OnePieceDAO governor;
    Box box;
    Timelock timelock;
    DevilFruitToken token;

    address public user = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 1 hours; // 3600
    uint256 public constant VOTING_DELAY = 1; // number of blocks till a vote is active
    uint256 public constant VOTING_PERIOD = 1 weeks; // 50400

    address[] proposers;
    address[] executors;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;

    function setUp() public {
        token = new DevilFruitToken();
        token.mint(user, INITIAL_SUPPLY);

        vm.startPrank(user);
        token.delegate(user);
        timelock = new Timelock(MIN_DELAY, proposers, executors);
        governor = new OnePieceDAO(token, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, user);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCannotUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 999;
        string memory description = "Store 999";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        string memory reason = "I'm am free to do anything I wish";

        uint8 voteWay = 1; // Voting Yes
        vm.prank(user);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.getNumber(), valueToStore);
    }
}
