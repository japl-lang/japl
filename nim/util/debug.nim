import ../meta/chunk
import ../meta/valueobject
import strformat


proc simpleInstruction(name: string, index: int): int =
    echo &"\tOpCode at offset: {name}\n"
    return index + 1


proc constantLongInstruction(name: string, chunk: Chunk, offset: int): int =
    # Rebuild the index
    var constantArray: array[3, uint8] = [chunk.code[offset + 1], chunk.code[offset + 2], chunk.code[offset + 3]]
    var constant: int
    copyMem(constant.addr, unsafeAddr(constantArray), sizeof(constantArray))
    echo &"\tOpCode at offset: {name}, points to {constant}"
    let obj = chunk.consts.values[constant]
    echo &"\tValue: {stringifyValue(obj)}\n\tKind: {obj.kind}\n"
    return offset + 4


proc constantInstruction(name: string, chunk: Chunk, offset: int): int =
    var constant = chunk.code[offset + 1]
    echo &"\tOpCode at offset: {name}, points to index {constant}"
    let obj = chunk.consts.values[constant]
    echo &"\tValue: {stringifyValue(obj)}\n\tKind: {obj.kind}\n"
    return offset + 2


proc disassembleInstruction*(chunk: Chunk, offset: int): int =
    echo &"Current offset: {offset}\nCurrent line: {chunk.lines[offset]}"
    var opcode = OpCode(chunk.code[offset])
    if opcode == OP_RETURN:
        result = simpleInstruction("OP_RETURN", offset)
    elif opcode == OP_CONSTANT:
        result = constantInstruction("OP_CONSTANT", chunk, offset)
    elif opcode == OP_CONSTANT_LONG:
        result = constantLongInstruction("OP_CONSTANT_LONG", chunk, offset)
    elif opcode == OP_NEGATE:
        result = simpleInstruction("OP_NEGATE", offset)
    elif opcode == OP_ADD:
        result = simpleInstruction("OP_ADD", offset)
    elif opcode == OP_MULTIPLY:
        result = simpleInstruction("OP_MULTIPLY", offset)
    elif opcode == OP_DIVIDE:
        result = simpleInstruction("OP_DIVIDE", offset)
    elif opcode == OP_SUBTRACT:
        result = simpleInstruction("OP_SUBTRACT", offset)
    elif opcode == OP_MOD:
        result = simpleInstruction("OP_MOD", offset)
    elif opcode == OP_POW:
        result = simpleInstruction("OP_POW", offset)
    elif opcode == OP_NIL:
        result = simpleInstruction("OP_NIL", offset)
    elif opcode == OP_TRUE:
        result = simpleInstruction("OP_TRUE", offset)
    elif opcode == OP_FALSE:
        result = simpleInstruction("OP_FALSE", offset)
    else:
        echo &"Unknown opcode {opcode} at index {offset}"
        result = offset + 1


proc disassembleChunk*(chunk: Chunk, name: string) =
    echo &"==== JAPL VM Debugger - Chunk '{name}' ====\n"
    var index = 0
    echo chunk.lines
    while index < chunk.code.len:
        index = disassembleInstruction(chunk, index)
    echo &"==== Debug session ended - Chunk '{name}' ===="

