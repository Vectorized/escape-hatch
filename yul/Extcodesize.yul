object "Extcodesize" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            mstore(returndatasize(), extcodesize(calldataload(0x01)))
            return(returndatasize(), msize())
        }
    }
}
