// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/SoladyTest.sol";
import {LibString} from "solady/utils/LibString.sol";

contract EscapeHatchTest is SoladyTest {
    address internal _escapeHatch;

    address internal constant _ALICE = address(bytes20(keccak256("alice")));
    address internal constant _BOB = address(bytes20(keccak256("bob")));
    address internal constant _CHARLIE = address(bytes20(keccak256("charlie")));

    function setUp() public {
        bytes memory runtime = vm.parseBytes(vm.readFile("test/data/runtime.txt"));
        bytes memory initcode = vm.parseBytes(vm.readFile("test/data/initcode.txt"));
        address instance;
        /// @solidity memory-safe-assembly
        assembly {
            instance := create(0, add(initcode, 0x20), mload(initcode))
        }
        assertEq(instance.code, runtime);
        _escapeHatch = instance;
    }

    function testForceSendEther() public {
        vm.deal(address(this), 100 ether);

        uint256 amount = 0.1 ether;
        _forceSendEther(_ALICE, amount);
        assertEq(_ALICE.balance, amount);

        vm.etch(_BOB, hex"3d3dfd");
        (bool success,) = _BOB.call{value: amount}("");
        assertEq(success, false);
        assertEq(_BOB.balance, 0);
        _forceSendEther(_BOB, amount);
        assertEq(_BOB.balance, amount);
    }

    function _forceSendEther(address to, uint256 amount) internal {
        bytes memory data = abi.encodePacked(hex"05", uint256(50000), uint256(uint160(to)));
        (bool success,) = _escapeHatch.call{value: amount}(data);
        assertEq(success, true);
    }
}
