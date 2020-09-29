import valueobject


type
    OpCode* = enum
        OP_CONSTANT = 0u8,
        OP_CONSTANT_LONG,
        OP_RETURN,
        OP_NEGATE,
        OP_ADD,
        OP_SUBTRACT,
        OP_DIVIDE,
        OP_MULTIPLY,
        OP_POW,
        OP_MOD,
        OP_NIL,
        OP_TRUE,
        OP_FALSE,
        OP_GREATER,
        OP_LESS,
        OP_EQUAL,
        OP_NOT,
        OP_SLICE,
        OP_SLICE_RANGE,
        OP_POP,
        OP_DEFINE_GLOBAL,
        OP_GET_GLOBAL,
        OP_SET_GLOBAL,
        OP_DELETE_GLOBAL,
        OP_SET_LOCAL,
        OP_GET_LOCAL,
        OP_DELETE_LOCAL,
        OP_JUMP_IF_FALSE,
        OP_JUMP,
        OP_LOOP,
        OP_BREAK,
        OP_SHR,
        OP_SHL,
        OP_NAN,
        OP_INF,
        OP_XOR,
        OP_CALL,
        OP_BOR,
        OP_BAND,
        OP_BNOT


    Chunk* = ref object
        consts*: ValueArray
        code*: seq[uint8]
        lines*: seq[int]


proc initChunk*(): Chunk =
    result = Chunk(consts: ValueArray(values: @[]), code: @[], lines: @[])


proc writeChunk*(self: Chunk, byt: uint8, line: int) =
    self.code.add(byt)
    self.lines.add(line)


proc writeChunk*(self: Chunk, bytes: array[3, uint8], line: int) =
    for byt in bytes:
        self.writeChunk(byt, line)


proc freeChunk*(self: var Chunk) =
    self.consts = ValueArray(values: @[])
    self.code = @[]
    self.lines = @[]


proc addConstant*(chunk: var Chunk, constant: Value): int =
    chunk.consts.values.add(constant)
    return len(chunk.consts.values) - 1  # The index of the constant


proc writeConstant*(chunk: var Chunk, constant: Value): array[3, uint8] =
    let index = chunk.addConstant(constant)
    result = cast[array[3, uint8]](index)

