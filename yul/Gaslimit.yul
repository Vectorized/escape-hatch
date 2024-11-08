object "Gaslimit" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            mstore(returndatasize(), gaslimit())
            return(returndatasize(), 0x20)
        }
    }
}
