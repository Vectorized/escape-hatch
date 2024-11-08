object "Basefee" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            let codeOffset := 0x33
            let codeSize := 0xffee
            if eq(1, chainid()) {
                codecopy(returndatasize(), codeOffset, codeSize)
                return(returndatasize(), codeSize)
            }
            codecopy(returndatasize(), add(codeOffset, codeSize), codeSize)
            return(returndatasize(), codeSize)
        }
    }
}
