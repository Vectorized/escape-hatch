object "Gasprice" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            mstore(returndatasize(), gasprice())
            return(returndatasize(), msize())
        }
    }
}
