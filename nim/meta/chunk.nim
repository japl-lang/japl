import valueobject


type
    OpCode* = enum
        OP_CONSTANT = 0u8,
        OP_CONSTANT_LONG,
        OP_RETURN,
    Chunk* = ref object
        consts*: ValueArray
        code*: seq[uint8]
        lines*: seq[int]


proc initChunk*(): Chunk =
    result = Chunk(consts: initValueArray(), code: @[], lines: @[])


proc writeChunk*(self: Chunk, byte: uint8, line: int) =
    self.code.add(byte)
    self.lines.add(line)

proc freeChunk*(self: var Chunk) =
    self.consts = ValueArray(values: @[])
    self.code = @[]
    self.lines = @[]


proc addConstant*(chunk: var Chunk, constant: Value): int =
    chunk.consts.values.add(constant)
    return len(chunk.consts.values) - 1  # The index of the constant
