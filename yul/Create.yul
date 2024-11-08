object "Create" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
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
    }
}
