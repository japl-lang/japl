import ../meta/chunk
import ../common
import strformat



proc simpleInstruction(name: string, index: int): int =
    echo &"\tInstruction at IP: {name}\n"
    return index + 1


proc byteInstruction(name: string, chunk: Chunk, offset: int): int =
    var slot = chunk.code[offset + 1]
    echo &"\tInstruction at IP: {name}, points to slot {slot}\n"
    return offset + 1


proc constantLongInstruction(name: string, chunk: Chunk, offset: int): int =
    # Rebuild the index
    var constantArray: array[3, uint8] = [chunk.code[offset + 1], chunk.code[offset + 2], chunk.code[offset + 3]]
    var constant: int
    copyMem(constant.addr, unsafeAddr(constantArray), sizeof(constantArray))
    echo &"\tInstruction at IP: {name}, points to slot {constant}"
    let obj = chunk.consts.values[constant]
    echo &"\tOperand: {stringify(obj)}\n\tValue kind: {obj.kind}\n"
    return offset + 4


proc constantInstruction(name: string, chunk: Chunk, offset: int): int =
    var constant = chunk.code[offset + 1]
    echo &"\tInstruction at IP: {name}, points to index {constant}"
    let obj = chunk.consts.values[constant]
    echo &"\tOperand: {stringify(obj)}\n\tValue kind: {obj.kind}\n"
    return offset + 2


proc jumpInstruction(name: string, chunk: Chunk, offset: int): int =
    var jump = uint16 (chunk.code[offset + 1] shr 8)
    jump = jump or chunk.code[offset + 2]
    echo &"\tInstruction at IP: {name}\n\tJump offset: {jump}\n"
    return offset + 3


proc disassembleInstruction*(chunk: Chunk, offset: int): int =
    echo &"Current IP position: {offset}\nCurrent line: {chunk.lines[offset]}"
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
    elif opcode == OP_NAN:
        result = simpleInstruction("OP_NAN", offset)
    elif opcode == OP_INF:
        result = simpleInstruction("OP_INF", offset)
    elif opcode == OP_SHL:
        result = simpleInstruction("OP_SHL", offset)
    elif opcode == OP_SHR:
        result = simpleInstruction("OP_SHR", offset)
    elif opcode == OP_XOR:
        result = simpleInstruction("OP_XOR", offset)
    elif opcode == OP_NOT:
        result = simpleInstruction("OP_NOT", offset)
    elif opcode == OP_EQUAL:
        result = simpleInstruction("OP_EQUAL", offset)
    elif opcode == OP_GREATER:
        result = simpleInstruction("OP_GREATER", offset)
    elif opcode == OP_LESS:
        result = simpleInstruction("OP_LESS", offset)
    elif opcode == OP_SLICE:
        result = simpleInstruction("OP_SLICE", offset)
    elif opcode == OP_SLICE_RANGE:
        result = simpleInstruction("OP_SLICE_RANGE", offset)
    elif opcode == OP_POP:
        result = simpleInstruction("OP_POP", offset)
    elif opcode == OP_DEFINE_GLOBAL:
        result = simpleInstruction("OP_DEFINE_GLOBAL", offset)
    elif opcode == OP_GET_GLOBAL:
        result = simpleInstruction("OP_GET_GLOBAL", offset)
    elif opcode == OP_SET_GLOBAL:
        result = simpleInstruction("OP_SET_GLOBAL", offset)
    elif opcode == OP_SET_LOCAL:
        result = byteInstruction("OP_SET_LOCAL", chunk, offset)
    elif opcode == OP_GET_LOCAL:
        result = byteInstruction("OP_GET_LOCAL", chunk, offset)
    elif opcode == OP_DELETE_LOCAL:
        result = byteInstruction("OP_DELETE_LOCAL", chunk, offset)
    elif opcode == OP_DELETE_GLOBAL:
        result = simpleInstruction("OP_DELETE_GLOBAL", offset)
    elif opcode == OP_JUMP_IF_FALSE:
        result = jumpInstruction("OP_JUMP_IF_FALSE", chunk, offset)
    elif opcode == OP_JUMP:
        result = jumpInstruction("OP_JUMP", chunk, offset)
    elif opcode == OP_LOOP:
        result = jumpInstruction("OP_LOOP", chunk, offset)
    elif opcode == OP_CALL:
        result = byteInstruction("OP_CALL", chunk, offset)
    else:
        echo &"Unknown opcode {opcode} at index {offset}"
        result = offset + 1


proc disassembleChunk*(chunk: Chunk, name: string) =
    echo &"==== JAPL VM Debugger - Chunk '{name}' ====\n"
    var index = 0
    while index < chunk.code.len:
        index = disassembleInstruction(chunk, index)
    echo &"==== Debug session ended - Chunk '{name}' ===="

