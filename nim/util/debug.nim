import ../meta/chunk
import ../meta/valueobject
import strformat


proc simpleInstruction(name: string, index: int): int =
    var index = index
    echo &"\tOpCode at offset: {name}"
    echo ""
    return index + 1


proc constantInstruction(name: string, chunk: Chunk, offset: int): int =
    var constant = chunk.code[offset + 1]
    echo &"\tOpCode at offset: {name}, points to index {constant}"
    printValue(chunk.consts.values[constant])
    echo ""
    return offset + 2


proc disassembleInstruction*(chunk: Chunk, offset: int): int =
    echo &"Current offset: {offset}\nCurrent line: {chunk.lines[offset]}"
    var opcode = OpCode(chunk.code[offset])
    if opcode == OP_RETURN:
        simpleInstruction("OP_RETURN", offset)
    elif opcode == OP_CONSTANT:
        constantInstruction("OP_CONSTANT", chunk, offset)
    else:
        echo &"Unknown opcode {opcode} at index {offset}"
        return offset + 1



proc disassembleChunk*(chunk: Chunk, name: string) =
    echo &"==== JAPL VM Debugger - Chunk '{name}' ====\n"
    var index = 0
    while index < chunk.code.len:
        index = disassembleInstruction(chunk, index)
    echo &"==== Debug session ended - Chunk '{name}' ===="
