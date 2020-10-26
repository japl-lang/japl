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

## This module takes chunks of bytecode, and prints their contents to the
## screen.

import ../meta/opcode
import ../types/jobject
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
    let obj = chunk.consts[constant]
    echo &"\tOperand: {stringify(obj)}\n\tValue kind: {obj.kind}\n"
    return offset + 4


proc constantInstruction(name: string, chunk: Chunk, offset: int): int =
    var constant = chunk.code[offset + 1]
    echo &"\tInstruction at IP: {name}, points to index {constant}"
    let obj = chunk.consts[constant]
    echo &"\tOperand: {stringify(obj)}\n\tValue kind: {obj.kind}\n"
    return offset + 2


proc jumpInstruction(name: string, chunk: Chunk, offset: int): int =
    var jump = uint16 (chunk.code[offset + 1] shr 8)
    jump = jump or chunk.code[offset + 2]
    echo &"\tInstruction at IP: {name}\n\tJump offset: {jump}\n"
    return offset + 3


proc disassembleInstruction*(chunk: Chunk, offset: int): int =
    ## Takes one bytecode instruction and prints it
    echo &"Current IP position: {offset}\nCurrent line: {chunk.lines[offset]}"
    var opcode = OpCode(chunk.code[offset])
    case opcode:
        of simpleInstructions:
            result = simpleInstruction($opcode, offset)
        of constantInstructions:
            result = constantInstruction($opcode, chunk, offset)
        of constantLongInstructions:
            result = constantLongInstruction($opcode, chunk, offset)
        of byteInstructions:
            result = byteInstruction($opcode, chunk, offset)
        of jumpInstructions:
            result = jumpInstruction($opcode, chunk, offset)
        else:
            echo &"Unknown opcode {opcode} at index {offset}"
            result = offset + 1


proc disassembleChunk*(chunk: Chunk, name: string) =
    ## Takes a chunk of bytecode, and prints it
    echo &"==== JAPL VM Debugger - Chunk '{name}' ====\n"
    var index = 0
    while index < chunk.code.len:
        index = disassembleInstruction(chunk, index)
    echo &"==== Debug session ended - Chunk '{name}' ===="

