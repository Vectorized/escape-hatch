object "ForceSendEther" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            if iszero(call(calldataload(0x01), calldataload(0x21), callvalue(), returndatasize(), returndatasize(), returndatasize(), returndatasize())) {
                mstore(0x00, or(calldataload(0x22), 0xff)) // Store address, followed by `SELFDESTRUCT`.
                mstore8(0x0a, 0x73) // Opcode `PUSH20`.
                if iszero(create(callvalue(), 0x0a, 0x16)) { revert(codesize(), 0x00) }
            }
            mstore(0x00, 1)
            return(0x00, msize())
        }
    }
}

