object "GasLimitedCall" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
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
    }
}

