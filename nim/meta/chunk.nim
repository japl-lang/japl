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
      ## Consts represents (TODO newdoc)
      ## Code represents (TODO newdoc)
      ## Lines represents (TODO newdoc)
      consts*: ValueArray
      code*: seq[uint8]
      lines*: seq[int]


proc newChunk*(): Chunk =
  ## The constructor for the type Chunk
  result = Chunk(consts: ValueArray(values: @[]), code: @[], lines: @[])


proc writeChunk*(self: Chunk, newByte: uint8, line: int) =
  ## Appends newByte at line to a chunk.
  self.code.add(newByte)
  self.lines.add(line)


proc writeChunk*(self: Chunk, bytes: array[3, uint8], line: int) =
  ## Appends bytes (an array of 3 bytes) to a chunk
  for cByte in bytes:
    self.writeChunk(cByte, line)


proc freeChunk*(self: Chunk) =
  ## Resets a chunk to its initial value.
  self.consts = ValueArray(values: @[])
  self.code = @[]
  self.lines = @[]


proc addConstant*(self: Chunk, constant: Value): int =
  ## Adds a constant to a chunk. Returns its index. 
  chunk.consts.values.add(constant)
  return self.consts.values.high()  # The index of the constant


proc writeConstant*(self: Chunk, constant: Value): array[3, uint8] =
  ## Writes a constant to a chunk. Returns its index casted to an array.
  ## TODO newdoc
  let index = chunk.addConstant(constant)
  result = cast[array[3, uint8]](index)

