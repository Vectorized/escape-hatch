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
        assertEq(instance.code, runtime);
        _escapeHatch = instance;
    }

    function testCreate() public {
        bytes memory data = abi.encodePacked(uint8(0x04), type(MockSimpleContract).creationCode, uint256(0));
        vm.deal(address(this), 100 ether);

        uint256 amount = 0.1 ether;
        (bool success, bytes memory result) = _escapeHatch.call{value: amount}(data);
        assertEq(success, true);
        address instance = abi.decode(result, (address));
        assertEq(MockSimpleContract(instance).FOO(), _FOO);
        assertEq(instance.balance, amount);
    }

    function testCreate2AndExtcodeOps() public {
        bytes memory data = abi.encodePacked(uint8(0x05), bytes32(0), type(MockSimpleContract).creationCode, uint256(0));
        vm.deal(address(this), 100 ether);

        uint256 amount = 0.1 ether;
        (bool success, bytes memory result) = _escapeHatch.call{value: amount}(data);
        assertEq(success, true);
        assertEq(MockSimpleContract(abi.decode(result, (address))).FOO(), _FOO);
        assertEq(abi.decode(result, (address)).balance, amount);

        data = abi.encodePacked(uint8(0x05), bytes32(uint256(1)), type(MockSimpleContract).creationCode, uint256(1));
        (success, result) = _escapeHatch.call{value: amount}(data);
        assertEq(success, false);
        assertEq(result, abi.encodePacked(MockSimpleContract.RevertedInConstructor.selector));

        data = abi.encodePacked(uint8(0x05), bytes32(uint256(2)), type(MockSimpleContract).creationCode, uint256(0));
        (success, result) = _escapeHatch.call{value: amount}(data);
        assertEq(success, true);
        assertEq(MockSimpleContract(abi.decode(result, (address))).FOO(), _FOO);

        address mock = abi.decode(result, (address));

        data = abi.encodePacked(uint8(0x01), uint256(uint160(mock)));
        (success, result) = _escapeHatch.call(data);
        assertEq(success, true);
        assertEq(abi.decode(result, (uint256)), mock.code.length);

        data = abi.encodePacked(uint8(0x02), uint256(uint160(mock)), uint256(0x05), uint256(0x11));
        (success, result) = _escapeHatch.call(data);
        assertEq(success, true);
        assertEq(result, LibBytes.slice(mock.code, uint256(0x05), uint256(0x05) + uint256(0x11)));

        data = abi.encodePacked(uint8(0x03), uint256(uint160(mock)));
        (success, result) = _escapeHatch.call(data);
        assertEq(success, true);
        assertEq(abi.decode(result, (bytes32)), keccak256(mock.code));
    }

    function testGasLimitedStaticcall() public {
        bytes memory sample = "3763124908736214987594532104983751cvbhadhgfwkeruiywtqerZ";
        bytes memory calldataToSelf = abi.encodeWithSignature("revertIfGasBelow(uint256,bytes)", uint256(50000), sample);
        bytes memory data =
            abi.encodePacked(uint8(0x08), uint256(30000), uint256(uint160(address(this))), calldataToSelf);
        (bool success, bytes memory result) = _escapeHatch.call(data);
        assertEq(success, false);
        assertEq(result, abi.encodePacked(GasLimitTooLow.selector));

        data = abi.encodePacked(uint8(0x08), uint256(90000), uint256(uint160(address(this))), calldataToSelf);
        (success, result) = _escapeHatch.call(data);
        assertEq(success, true);
        assertEq(result, abi.encode(sample));

        calldataToSelf = abi.encodeWithSignature("revertIfGasBelowOrSet(uint256,bytes)", uint256(50000), sample);
        data = abi.encodePacked(uint8(0x08), uint256(90000), uint256(uint160(address(this))), calldataToSelf);
        (success, result) = _escapeHatch.call(data);
        assertEq(success, false);
    }

    function revertIfGasBelow(uint256 thres, bytes memory data) public view returns (bytes memory) {
        if (gasleft() < thres) revert GasLimitTooLow();
        return data;
    }

    function testGasLimitedCall() public {
        bytes memory sample = "3763124908736214987594532104983751cvbhadhgfwkeruiywtqerZ";
        bytes memory calldataToSelf =
            abi.encodeWithSignature("revertIfGasBelowOrSet(uint256,bytes)", uint256(50000), sample);
        bytes memory data =
            abi.encodePacked(uint8(0x07), uint256(30000), uint256(uint160(address(this))), calldataToSelf);
        (bool success, bytes memory result) = _escapeHatch.call(data);
        assertEq(success, false);
        assertEq(result, abi.encodePacked(GasLimitTooLow.selector));
        vm.deal(address(this), 100 ether);

        data = abi.encodePacked(uint8(0x07), uint256(90000), uint256(uint160(address(this))), calldataToSelf);
        uint256 amount = 0.1 ether;
        (success, result) = _escapeHatch.call{value: amount}(data);
        assertEq(success, true);
        assertEq(result, abi.encode(sample));
        assertEq(_dataAndValueHash, keccak256(abi.encode(amount, sample)));
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
        (bool success,) = _escapeHatch.call{value: amount}(data);
        assertEq(success, true);
    }
}
