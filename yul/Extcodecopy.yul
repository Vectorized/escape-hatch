object "Extcodecopy" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            let n := calldataload(0x41)
            extcodecopy(
                calldataload(0x01),
                returndatasize(),
                calldataload(0x21),
                n
            )
            return(returndatasize(), n)
        }
    }
}
