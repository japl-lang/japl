## The module dedicated to the type Chunk.
## A chunk is a piece of bytecode.

import valueobject


type
    OpCode* {.pure.} = enum
      ## Enum of possible opcodes.
      Constant = 0u8,
      ConstantLong,
      Return,
      Negate,
      Add,
      Subtract,
      Divide,
      Multiply,
      Pow,
      Mod,
      Nil,
      True,
      False,
      Greater,
      Less,
      Equal,
      Not,
      Slice,
      SliceRange,
      Pop,
      DefineGlobal,
      GetGlobal,
      SetGlobal,
      DeleteGlobal,
      SetLocal,
      GetLocal,
      DeleteLocal,
      JumpIfFalse,
      Jump,
      Loop,
      Breal,
      Shr,
      Shl,
      Nan,
      Inf,
      Xor,
      Call,
      Bor,
      Band,
      Bnot


    Chunk* = ref object
      ## A piece of bytecode.
      consts*: ValueArray
      code*: seq[uint8]
      lines*: seq[int]


proc newChunk*(): Chunk =
  ## 
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

