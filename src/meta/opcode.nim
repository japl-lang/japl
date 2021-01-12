# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Implementation for bytecode chunks and the VM's opcodes
## A chunk is a piece of bytecode together with its constants

import ../types/baseObject


type
    Chunk* = ref object   # TODO: This shouldn't be here, but Function needs it. Consider refactoring
        ## A piece of bytecode.
        ## Consts represents the constants table the code is referring to
        ## Code is the compiled bytecode
        ## Lines maps bytecode instructions to line numbers (1 to 1 correspondence)
        consts*: seq[ptr Obj]
        code*: seq[uint8]
        lines*: seq[int]   # TODO: Run-length encoding
    OpCode* {.pure.} = enum
        ## Enum of possible opcodes
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
        GetItem,
        Slice,
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
        Break,
        Shr,
        Shl,
        Nan,
        Inf,
        Xor,
        Call,
        Bor,
        Band,
        Bnot,
        Is,
        As


    
const simpleInstructions* = {OpCode.Return, OpCode.Add, OpCode.Multiply,
                             OpCode.Divide, OpCode.Subtract,
                             OpCode.Mod, OpCode.Pow, OpCode.Nil,
                             OpCode.True, OpCode.False, OpCode.Nan,
                             OpCode.Inf, OpCode.Shl, OpCode.Shr,
                             OpCode.Xor, OpCode.Not, OpCode.Equal,
                             OpCode.Greater, OpCode.Less, OpCode.GetItem,
                             OpCode.Slice, OpCode.Pop, OpCode.Negate,
                             OpCode.Is, OpCode.As}
const constantInstructions* = {OpCode.Constant, OpCode.DefineGlobal,
                         OpCode.GetGlobal, OpCode.SetGlobal,
                         OpCode.DeleteGlobal}

const constantLongInstructions* = {OpCode.ConstantLong}
const byteInstructions* = {OpCode.SetLocal, OpCode.GetLocal, OpCode.DeleteLocal,
                           OpCode.Call}
const jumpInstructions* = {OpCode.JumpIfFalse, OpCode.Jump, OpCode.Loop}


proc newChunk*(): Chunk =
    ## Initializes a new, empty chunk
    result = Chunk(consts: @[], code: @[], lines: @[])


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
    self.consts = @[]
    self.code = @[]
    self.lines = @[]


proc addConstant*(self: Chunk, constant: ptr Obj): int =
    ## Adds a constant to a chunk. Returns its index. 
    self.consts.add(constant)
    return self.consts.high()  # The index of the constant


proc writeConstant*(self: Chunk, constant: ptr Obj): array[3, uint8] =
    ## Writes a constant to a chunk. Returns its index casted to an array.
    ## TODO newdoc
    let index = self.addConstant(constant)
    result = cast[array[3, uint8]](index)
  
