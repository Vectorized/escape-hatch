// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/SoladyTest.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {LibString} from "solady/utils/LibString.sol";

contract MockSimpleContract {
    error RevertedInConstructor();

    string public constant FOO = "The quick brown fox jumps over the lazy dog.";

    constructor(bool revertOnConstructor) payable {
        if (revertOnConstructor) revert RevertedInConstructor();
    }
}

contract EscapeHatchTest is SoladyTest {
    error GasLimitTooLow();

    address internal _escapeHatch;

    string internal constant _FOO = "The quick brown fox jumps over the lazy dog.";

    address internal constant _ALICE = address(bytes20(keccak256("alice")));
    address internal constant _BOB = address(bytes20(keccak256("bob")));
    address internal constant _CHARLIE = address(bytes20(keccak256("charlie")));

    bytes32 internal _dataAndValueHash;

    // file path                     jump section  runtime bytes
    // yul/Extcodesize.yul           0x01          10
    // yul/Extcodecopy.yul           0x02          15
    // yul/Extcodehash.yul           0x03          10
    // yul/Create.yul                0x04          42
    // yul/Create2.yul               0x05          45
    // yul/ForceSendEther.yul        0x06          51
    // yul/GasLimitedCall.yul        0x07          45
    // yul/GasLimitedStaticcall.yul  0x08          44
    // yul/Gas.yul                   0x09          7
    // yul/Gasprice.yul              0x0a          7
    // yul/Gaslimit.yul              0x0b          7
    // yul/Basefee.yul               0x0c          8

    function setUp() public {
        bytes memory runtime = vm.parseBytes(vm.readFile("test/data/runtime.txt"));
        bytes memory initcode = vm.parseBytes(vm.readFile("test/data/initcode.txt"));
        address instance;
        /// @solidity memory-safe-assembly
        assembly {
            instance := create(0, add(initcode, 0x20), mload(initcode))
        }
        emit LogBytes32(keccak256(initcode));
        assertEq(instance.code, runtime);
        _escapeHatch = instance;
    }

    struct _TestTemps {
        bytes data;
        uint256 amount;
        bool success;
        bytes result;
        address mock;
        bytes sample;
        bytes dataToSelf;
    }

    function testCreate() public {
        _TestTemps memory t;
        t.data = abi.encodePacked(uint8(0x04), type(MockSimpleContract).creationCode, uint256(0));
        vm.deal(address(this), 100 ether);

        t.amount = 0.1 ether;
        (t.success, t.result) = _escapeHatch.call{value: t.amount}(t.data);
        assertEq(t.success, true);
        t.mock = abi.decode(t.result, (address));
        assertEq(MockSimpleContract(t.mock).FOO(), _FOO);
        assertEq(t.mock.balance, t.amount);
    }

    function testCreate2AndExtcodeOps() public {
        _TestTemps memory t;
        t.data = abi.encodePacked(uint8(0x05), bytes32(0), type(MockSimpleContract).creationCode, uint256(0));
        vm.deal(address(this), 100 ether);

        t.amount = 0.1 ether;
        (t.success, t.result) = _escapeHatch.call{value: t.amount}(t.data);
        assertEq(t.success, true);
        t.mock = abi.decode(t.result, (address));
        assertEq(MockSimpleContract(t.mock).FOO(), _FOO);
        assertEq(t.mock.balance, t.amount);

        t.data = abi.encodePacked(uint8(0x05), bytes32(uint256(1)), type(MockSimpleContract).creationCode, uint256(1));
        (t.success, t.result) = _escapeHatch.call{value: t.amount}(t.data);
        assertEq(t.success, false);
        assertEq(t.result, abi.encodePacked(MockSimpleContract.RevertedInConstructor.selector));

        t.data = abi.encodePacked(uint8(0x05), bytes32(uint256(2)), type(MockSimpleContract).creationCode, uint256(0));
        (t.success, t.result) = _escapeHatch.call{value: t.amount}(t.data);
        assertEq(t.success, true);
        t.mock = abi.decode(t.result, (address));
        assertEq(MockSimpleContract(t.mock).FOO(), _FOO);

        t.data = abi.encodePacked(uint8(0x01), uint256(uint160(t.mock)));
        (t.success, t.result) = _escapeHatch.call(t.data);
        assertEq(t.success, true);
        assertEq(abi.decode(t.result, (uint256)), t.mock.code.length);

        t.data = abi.encodePacked(uint8(0x02), uint256(uint160(t.mock)), uint256(0x05), uint256(0x11));
        (t.success, t.result) = _escapeHatch.call(t.data);
        assertEq(t.success, true);
        assertEq(t.result, LibBytes.slice(t.mock.code, uint256(0x05), uint256(0x05) + uint256(0x11)));

        t.data = abi.encodePacked(uint8(0x03), uint256(uint160(t.mock)));
        (t.success, t.result) = _escapeHatch.call(t.data);
        assertEq(t.success, true);
        assertEq(abi.decode(t.result, (bytes32)), keccak256(t.mock.code));
    }

    function testGasLimitedStaticcall() public {
        _TestTemps memory t;
        t.sample = "3763124908736214987594532104983751cvbhadhgfwkeruiywtqerZ";
        t.dataToSelf = abi.encodeWithSignature("revertIfGasBelow(uint256,bytes)", uint256(50000), t.sample);
        t.data = abi.encodePacked(uint8(0x08), uint256(30000), uint256(uint160(address(this))), t.dataToSelf);
        (t.success, t.result) = _escapeHatch.call(t.data);
        assertEq(t.success, false);
        assertEq(t.result, abi.encodePacked(GasLimitTooLow.selector));

        t.data = abi.encodePacked(uint8(0x08), uint256(90000), uint256(uint160(address(this))), t.dataToSelf);
        (t.success, t.result) = _escapeHatch.call(t.data);
        assertEq(t.success, true);
        assertEq(t.result, abi.encode(t.sample));

        t.dataToSelf = abi.encodeWithSignature("revertIfGasBelowOrSet(uint256,bytes)", uint256(50000), t.sample);
        t.data = abi.encodePacked(uint8(0x08), uint256(90000), uint256(uint160(address(this))), t.dataToSelf);
        (t.success, t.result) = _escapeHatch.call(t.data);
        assertEq(t.success, false);
    }

    function revertIfGasBelow(uint256 thres, bytes memory data) public view returns (bytes memory) {
        if (gasleft() < thres) revert GasLimitTooLow();
        return data;
    }

    function testGasLimitedCall() public {
        _TestTemps memory t;
        t.sample = "3763124908736214987594532104983751cvbhadhgfwkeruiywtqerZ";
        t.dataToSelf = abi.encodeWithSignature("revertIfGasBelowOrSet(uint256,bytes)", uint256(50000), t.sample);
        t.data = abi.encodePacked(uint8(0x07), uint256(30000), uint256(uint160(address(this))), t.dataToSelf);
        (t.success, t.result) = _escapeHatch.call(t.data);
        assertEq(t.success, false);
        assertEq(t.result, abi.encodePacked(GasLimitTooLow.selector));
        vm.deal(address(this), 100 ether);

        t.data = abi.encodePacked(uint8(0x07), uint256(90000), uint256(uint160(address(this))), t.dataToSelf);
        t.amount = 0.1 ether;
        (t.success, t.result) = _escapeHatch.call{value: t.amount}(t.data);
        assertEq(t.success, true);
        assertEq(t.result, abi.encode(t.sample));
        assertEq(_dataAndValueHash, keccak256(abi.encode(t.amount, t.sample)));
    }

    function revertIfGasBelowOrSet(uint256 thres, bytes memory data) public payable returns (bytes memory) {
        if (gasleft() < thres) revert GasLimitTooLow();
        _dataAndValueHash = keccak256(abi.encode(msg.value, data));
        return data;
    }

    function testGas() public view {
        bytes memory data = abi.encodePacked(uint8(0x09));
        (bool success, bytes memory result) = _escapeHatch.staticcall(data);
        assertEq(success, true);
        assertGt(abi.decode(result, (uint256)), 0);
    }

    function testGasprice() public {
        vm.txGasPrice(12345);
        bytes memory data = abi.encodePacked(uint8(0x0a));
        (bool success, bytes memory result) = _escapeHatch.staticcall(data);
        assertEq(success, true);
        assertEq(abi.decode(result, (uint256)), 12345);
    }

    function testGaslimit() public view {
        bytes memory data = abi.encodePacked(uint8(0x0b));
        (bool success, bytes memory result) = _escapeHatch.staticcall(data);
        assertEq(success, true);
        assertEq(abi.decode(result, (uint256)), block.gaslimit);
    }

    function testBaseFee() public {
        vm.fee(112233);
        bytes memory data = abi.encodePacked(uint8(0x0c));
        (bool success, bytes memory result) = _escapeHatch.staticcall(data);
        assertEq(success, true);
        assertEq(abi.decode(result, (uint256)), 112233);
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
        bytes memory data = abi.encodePacked(uint8(0x06), uint256(50000), uint256(uint160(to)));
        (bool success, bytes memory result) = _escapeHatch.call{value: amount}(data);
        assertEq(success, true);
        assertEq(result, abi.encode(uint256(1)));
    }
}
