object "ForceSendEther" {
    code {
        datacopy(returndatasize(), dataoffset("runtime"), datasize("runtime"))
        return(returndatasize(), datasize("runtime"))
    }
    object "runtime" {
        code {
            if iszero(call(calldataload(0x01), calldataload(0x21), callvalue(), codesize(), returndatasize(), codesize(), returndatasize())) {
                mstore(0x00, calldataload(0x21)) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(callvalue(), 0x0b, 0x16)) { revert(codesize(), 0x00) }
            }
            mstore(0x00, 1)
            return(0x00, 0x20)
        }
    }
}

