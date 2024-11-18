object "CombinedExample" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            switch calldataload(returndatasize())
            case 0 {
                mstore(returndatasize(), extcodesize(calldataload(0x01)))
                return(returndatasize(), msize())
            }
            case 1 {
                let n := calldataload(0x41)
                extcodecopy(
                    calldataload(0x01),
                    returndatasize(),
                    calldataload(0x21),
                    n
                )
                return(returndatasize(), n)
            }
            case 2 {
                mstore(returndatasize(), extcodehash(calldataload(0x01)))
                return(returndatasize(), msize())
            }
            case 3 {
                let n := mul(sub(calldatasize(), 0x01), gt(calldatasize(), 0x01))
                calldatacopy(returndatasize(), 0x01, n)
                let instance := create(callvalue(), returndatasize(), n)
                if iszero(instance) {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(0x00, instance)
                return(0x00, 0x20)
            }
            case 4 {
                let s0 := calldataload(0x01)
                let n := mul(sub(calldatasize(), 0x21), gt(calldatasize(), 0x21))
                calldatacopy(returndatasize(), 0x21, n)
                let instance := create2(callvalue(), returndatasize(), n, s0)
                if iszero(instance) {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(0x00, instance)
                return(0x00, 0x20)
            }
            case 5 {
                if iszero(call(calldataload(0x01), calldataload(0x21), callvalue(), returndatasize(), returndatasize(), returndatasize(), returndatasize())) {
                    mstore(0x00, or(calldataload(0x22), 0xff)) // Store address, followed by `SELFDESTRUCT`.
                    mstore8(0x0a, 0x73) // Opcode `PUSH20`.
                    if iszero(create(callvalue(), 0x0a, 0x16)) { revert(codesize(), 0x00) }
                }
                mstore(0x00, 1)
                return(0x00, msize())
            }
            case 6 {
                let s0 := returndatasize()
                let s1 := returndatasize()
                let n := mul(sub(calldatasize(), 0x41), gt(calldatasize(), 0x41))
                calldatacopy(returndatasize(), 0x41, n)
                let success := call(calldataload(0x01), calldataload(0x21), callvalue(), returndatasize(), n, s1, s0)
                returndatacopy(0x00, 0x00, returndatasize())
                if iszero(success) {
                    revert(0x00, returndatasize())
                }
                return(0x00, returndatasize())
            }
            case 7 {
                let s0 := returndatasize()
                let s1 := returndatasize()
                let n := mul(sub(calldatasize(), 0x41), gt(calldatasize(), 0x41))
                calldatacopy(returndatasize(), 0x41, n)
                let success := staticcall(calldataload(0x01), calldataload(0x21), returndatasize(), n, s1, s0)
                returndatacopy(0x00, 0x00, returndatasize())
                if iszero(success) {
                    revert(0x00, returndatasize())
                }
                return(0x00, returndatasize())
            }
            case 8 {
                mstore(returndatasize(), gas())
                return(returndatasize(), msize())
            }
            case 9 {
                mstore(returndatasize(), gasprice())
                return(returndatasize(), msize())
            }
            case 10 {
                mstore(returndatasize(), gaslimit())
                return(returndatasize(), msize())
            }
            case 11 {
                mstore(returndatasize(), basefee())
                return(returndatasize(), msize())
            }
            default {
                stop()
            }
        }
    }
}
