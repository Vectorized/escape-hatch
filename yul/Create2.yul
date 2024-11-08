object "Create2" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
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
    }
}
