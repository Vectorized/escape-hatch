object "Extcodehash" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            mstore(returndatasize(), extcodehash(calldataload(0x01)))
            return(returndatasize(), msize())
        }
    }
}
