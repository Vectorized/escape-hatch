object "Basefee" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            mstore(returndatasize(), basefee())
            return(returndatasize(), msize())
        }
    }
}
