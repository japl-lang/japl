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
import ../types/baseObject
import ../types/methods
import ../types/arraylist
import strformat
import terminal
import ../multibyte

proc printName(name: string) =
    setForegroundColor(fgGreen)
    write stdout, name
    setForegroundColor(fgDefault)

proc nl =
    write stdout, "\n"

proc simpleInstruction(name: string, index: int): int =
    write stdout, &"DEBUG - VM:\tInstruction -> "
    printName(name)
    nl()
    return index + 1


proc byteInstruction(name: string, chunk: Chunk, offset: int): int =
    var slot = chunk.code[offset + 1]
    write stdout, &"DEBUG - VM:\tInstruction -> "
    printName(name)
    write stdout, &", points to slot {slot}"
    nl()
    return offset + 2


proc constantInstruction(name: string, chunk: Chunk, offset: int): int =
    # Rebuild the index
    var constantArray: array[3, uint8] = [chunk.code[offset + 1], chunk.code[offset + 2], chunk.code[offset + 3]]
    var constant: int
    copyMem(constant.addr, constantArray.addr, sizeof(constantArray))
    write stdout, &"DEBUG - VM:\tInstruction -> "
    printName(name)
    write stdout, &", points to slot {constant}"
    nl()
    let obj = chunk.consts[constant]
    echo &"DEBUG - VM:\tOperand -> {stringify(obj)}\nDEBUG - VM:\tValue kind -> {obj.kind}"
    return offset + 4


proc jumpInstruction(name: string, chunk: Chunk, offset: int): int =
    var jumpArray: array[2, uint8] = [chunk.code[offset + 1], chunk.code[offset + 2]]
    write stdout, &"DEBUG - VM:\tInstruction -> "
    printName(name)
    write stdout, &"\nDEBUG - VM:\tJump size -> {jumpArray.fromDouble()} ( = {$jumpArray[0]}, {$jumpArray[1]})"
    nl()
    return offset + 3


proc disassembleInstruction*(chunk: Chunk, offset: int): int =
    ## Takes one bytecode instruction and prints it
    echo &"DEBUG - VM:\tOffset: {offset}\nDEBUG - VM:\tLine: {chunk.lines[offset]}"
    var opcode = OpCode(chunk.code[offset])
    case opcode:
        of simpleInstructions:
            result = simpleInstruction($opcode, offset)
        of constantInstructions:
            result = constantInstruction($opcode, chunk, offset)
        of byteInstructions:
            result = byteInstruction($opcode, chunk, offset)
        of jumpInstructions:
            result = jumpInstruction($opcode, chunk, offset)
        else:
            echo &"DEBUG - Unknown opcode {opcode} at index {offset}"
            result = offset + 1


proc disassembleChunk*(chunk: Chunk, name: string) =
    ## Takes a chunk of bytecode, and prints it
    echo &"==== JAPL VM Debugger - Chunk '{name}' ====\n"
    var index = 0
    while index < chunk.code.len:
        index = disassembleInstruction(chunk, index)
    echo &"==== Debug session ended - Chunk '{name}' ===="
