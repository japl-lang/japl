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

## A stack-based bytecode virtual machine implementation.
## This is the entire runtime environment for JAPL

import algorithm
import strformat
import math
import lenientops
import config
import compiler
import tables
import meta/opcode
import meta/frame
import types/exceptions
import types/jobject
import types/jstring
import types/function
import memory
when DEBUG_TRACE_VM:
    import util/debug


## Move these into appropriate int/float modules
proc `**`(a, b: int): int = pow(a.float, b.float).int
proc `**`(a, b: float): float = pow(a, b)


type
    KeyboardInterrupt* = object of CatchableError

    InterpretResult = enum
        OK,
        COMPILE_ERROR,
        RUNTIME_ERROR
    VM* = ref object    # The VM object
        lastPop*: ptr Obj
        frameCount*: int
        source*: string
        frames*: seq[CallFrame]
        stack*: seq[ptr Obj]
        stackTop*: int
        objects*: seq[ptr Obj]
        globals*: Table[string, ptr Obj]
        file*: string


func handleInterrupt() {.noconv.} =
    ## Raises an appropriate exception
    ## to let us catch and handle
    ## Ctrl+C gracefully
    raise newException(KeyboardInterrupt, "Ctrl+C")


proc resetStack*(self: var VM) =
    ## Resets the VM stack to a blank state
    self.stack = @[]
    self.frames = @[]
    self.frameCount = 0
    self.stackTop = 0



proc error*(self: var VM, error: ptr JAPLException) =
    ## Reports runtime errors with a nice traceback
    var previous = ""  # All this stuff seems overkill, but it makes the traceback look nicer
    var repCount = 0   # and if we are here we are far beyond a point where performance matters
    var mainReached = false
    var output = ""
    stderr.write("Traceback (most recent call last):\n")
    for frame in reversed(self.frames):
        if mainReached:
            break
        var function = frame.function
        var line = function.chunk.lines[frame.ip]
        if function.name == nil:
            output = &"  File '{self.file}', line {line}, in '<module>':"
            mainReached = true
        else:
            output = &"  File '{self.file}', line {line}, in {stringify(function.name)}():"
        if output != previous:
            if repCount > 0:
                stderr.write(&"   ...previous line repeated {repCount} more times...\n")
            repCount = 0
            previous = output
            stderr.write(&"{output}\n")
        else:
            repCount += 1
    stderr.write(error.stringify())
    stderr.write("\n")
    self.resetStack()


proc pop*(self: var VM): ptr Obj =
    ## Pops a value off the stack
    result = self.stack.pop()
    self.stackTop -= 1


proc push*(self: var VM, obj: ptr Obj) =
    ## Pushes an object onto the stack
    self.stack.add(obj)
    self.stackTop += 1


proc peek*(self: var VM, distance: int): ptr Obj =
    ## Peeks an object (at a given distance from the
    ## current index) from the stack
    return self.stack[self.stackTop - distance - 1]


template addObject*(self: ptr VM, obj: ptr Obj): untyped =
    ## Stores an object in the VM's internal
    ## list of objects in order to reclaim
    ## its memory later
    let temp = obj
    self.objects.add(temp)
    temp


# TODO: Move this to jobject.nim
proc slice(self: var VM): bool =
    ## Handles single-operator slice expressions
    ## (consider moving this to an appropriate
    ## slice method)
    var idx = self.pop()
    var peeked = self.pop()
    case peeked.kind:
        of ObjectType.String:
            var str = peeked.toStr()
            if not idx.isInt():
                self.error(newTypeError("string indeces must be integers"))
                return false
            else:
                var index: int = idx.toInt()
                if index < 0:
                    index = len(str) + idx.toInt()
                    if index < 0:    # If even now it is less than 0 than it is out of bounds
                        self.error(newIndexError("string index out of bounds"))
                        return false
                elif index - 1 > len(str) - 1:
                    self.error(newIndexError("string index out of bounds"))
                    return false
                else:
                    self.push(addObject(addr self, jobject.newString(&"{str[index]}")))
                    return true
        else:
            self.error(newTypeError(&"unsupported slicing for object of type '{peeked.typeName()}'"))
            return false

# TODO: Move this to jobject.nim
proc sliceRange(self: var VM): bool =
    ## Handles slices when there's both a start
    ## and an end index (even implicit ones)
    var sliceEnd = self.pop()
    var sliceStart = self.pop()
    var popped = self.pop()
    case popped.kind:
        of ObjectType.String:
            var str = popped.toStr()
            if sliceEnd.isNil():
                sliceEnd = len(str).asInt()
            if sliceStart.isNil():
                sliceStart = asInt(0)
            elif not sliceStart.isInt() or not sliceEnd.isInt():
                self.error(newTypeError("string indexes must be integers"))
                return false
            else:
                var startIndex = sliceStart.toInt()
                var endIndex = sliceEnd.toInt()
                if startIndex < 0:
                    sliceStart = (len(str) + sliceStart.toInt()).asInt()
                    if startIndex < 0:
                        sliceStart = (len(str) + sliceEnd.toInt()).asInt()
                elif startIndex - 1 > len(str) - 1:
                    self.push(addObject(addr self, jobject.newString("")))
                    return true
                if endIndex - 1 > len(str) - 1:
                    sliceEnd = len(str).asInt()
                if startIndex > endIndex:
                    self.push(addObject(addr self, jobject.newString("")))
                    return true
                self.push(addObject(addr self, jobject.newString(str[sliceStart.toInt()..<sliceEnd.toInt()])))
                return true
        else:
            self.error(newTypeError(&"unsupported slicing for object of type '{popped.typeName()}'"))
            return false

proc call(self: var VM, function: ptr Function, argCount: uint8): bool =
    ## Sets up the call frame and performs error checking
    ## when calling callables
    var argCount = int argCount
    if argCount != function.arity:
        self.error(newTypeError(&"function '{stringify(function.name)}' takes {function.arity} argument(s), got {argCount}"))
        return false
    if self.frameCount == FRAMES_MAX:
        self.error(newRecursionError("max recursion depth exceeded"))
        return false
    var frame = CallFrame(function: function, ip: 0, slot: argCount, endSlot: self.stackTop, stack: self.stack)   # TODO: 
    # Check why this raises NilAccessError when high recursion limit is hit
    self.frames.add(frame)
    self.frameCount += 1
    return true


proc callValue(self: var VM, callee: ptr Obj, argCount: uint8): bool =
    ## Wrapper around call() to do type checking
    case callee.kind:
        of ObjectType.Function:
            return self.call(cast[ptr Function](callee), argCount)
        else:
            discard  # Not callable
    self.error(newTypeError(&"object of type '{callee.typeName}' is not callable"))
    return false


proc run(self: var VM, repl: bool): InterpretResult =
    ## Chews trough bytecode instructions executing
    ## them one at a time, this is the runtime's
    ## main loop
    var frame = self.frames[self.frameCount - 1]
    template readByte: untyped =
        ## Reads a single byte from the current
        ## frame's chunk of bytecode
        inc(frame.ip)
        frame.function.chunk.code[frame.ip - 1]
    template readBytes: untyped =
        ## Reads and decodes 3 bytes from the
        ## current frame's chunk into an integer
        var arr = [readByte(), readByte(), readByte()]
        var index: int
        copyMem(index.addr, unsafeAddr(arr), sizeof(arr))
        index
    template readShort: untyped =
        ## Reads a 16 bit number from the
        ## current frame's chunk
        inc(frame.ip)
        inc(frame.ip)
        cast[uint16]((frame.function.chunk.code[frame.ip - 2] shl 8) or frame.function.chunk.code[frame.ip - 1])
    template readConstant: ptr Obj =
        ## Reads a constant from the current
        ## frame's constant table
        frame.function.chunk.consts[int(readByte())]
    template readLongConstant: ptr Obj =
        ## Reads a long constant from the
        ## current frame's constant table
        var arr = [readByte(), readByte(), readByte()]
        var idx: int
        copyMem(idx.addr, unsafeAddr(arr), sizeof(arr))
        frame.function.chunk.consts[idx]
    var instruction: uint8
    var opcode: OpCode
    while true:
        {.computedgoto.}   # See https://nim-lang.org/docs/manual.html#pragmas-computedgoto-pragma
        instruction = readByte()
        opcode = OpCode(instruction)
        when DEBUG_TRACE_VM:    # Insight inside the VM
            stdout.write("Current VM stack status: [")
            for v in self.stack:
                stdout.write(stringify(v))
                stdout.write(", ")
            stdout.write("]\n")
            stdout.write("Current global scope status: {")
            for k, v in self.globals.pairs():
                stdout.write(k)
                stdout.write(": ")
                stdout.write(stringify(v))
            stdout.write("}\n")
            stdout.write("Current frame type:")
            if frame.function.name == nil:
                stdout.write(" main\n")
            else:
                stdout.write(&" function, '{frame.function.name.stringify()}'\n")
            stdout.write(&"Current frame count: {self.frameCount}\n")
            stdout.write("Current frame stack status: ")
            stdout.write("[")
            for e in self.stack[frame.slot..self.stackTop - 1]:
                stdout.write(stringify(e))
                stdout.write(", ")
            stdout.write("]\n")
            discard disassembleInstruction(frame.function.chunk, frame.ip - 1)
        case opcode:   # Main OpCodes dispatcher
            of OpCode.Constant:
                var constant: ptr Obj = readConstant()
                self.push(constant)
            of OpCode.ConstantLong:
                var constant: ptr Obj = readLongConstant()
                self.push(constant)
            of OpCode.Negate:   # TODO: Call appropriate methods
                discard
            of OpCode.Add:
                discard
            of OpCode.Shl:
                discard
            of OpCode.Shr:
                discard
            of OpCode.Xor:
                discard
            of OpCode.Bor:
                discard
            of OpCode.Bnot:
                discard
            of OpCode.Band:
                discard
            of OpCode.Subtract:
                discard
            of OpCode.Divide:
                discard
            of OpCode.Multiply:
                discard
            of OpCode.Mod:
                discard
            of OpCode.Pow:
                discard
            of OpCode.True:
                self.push((true).asBool())
            of OpCode.False:
                self.push((false).asBool())
            of OpCode.Nil:
                self.push(asNil())
            of OpCode.Nan:
                self.push(asNan())
            of OpCode.Inf:
                self.push(asInf())
            of OpCode.Not:
                self.push(self.pop().isFalsey().asBool())
            of OpCode.Equal:
                discard
            of OpCode.Less:
                discard
            of OpCode.Greater:
                discard
            of OpCode.Slice:
                if not self.slice():
                    return RUNTIME_ERROR
            of OpCode.SliceRange:
                if not self.sliceRange():
                    return RUNTIME_ERROR
            of OpCode.DefineGlobal:
                if frame.function.chunk.consts.len > 255:
                    var constant = readLongConstant().toStr()
                    self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().toStr()
                    self.globals[constant] = self.peek(0)
                discard self.pop()   # This will help when we have a custom GC
            of OpCode.GetGlobal:
                if frame.function.chunk.consts.len > 255:
                    var constant = readLongConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.push(self.globals[constant])
                else:
                    var constant = readConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.push(self.globals[constant])
            of OpCode.SetGlobal:
                if frame.function.chunk.consts.len > 255:
                    var constant = readLongConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"assignment to undeclared name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"assignment to undeclared name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals[constant] = self.peek(0)
            of OpCode.DeleteGlobal:
                # This OpCode, as well as DeleteLocal, is currently unused due to potential issues with the GC
                if frame.function.chunk.consts.len > 255:
                    var constant = readLongConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals.del(constant)
                else:
                    var constant = readConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals.del(constant)
            of OpCode.GetLocal:
                if frame.len > 255:
                    var slot = readBytes()
                    self.push(frame[slot])
                else:
                    var slot = readByte()
                    self.push(frame[int slot])
            of OpCode.SetLocal:
                if frame.len > 255:
                    var slot = readBytes()
                    frame[slot] = self.peek(0)
                else:
                    var slot = readByte()
                    frame[int slot] = self.peek(0)
            of OpCode.DeleteLocal:
                # Unused due to GC potential issues
                if frame.len > 255:
                    var slot = readBytes()
                    frame.delete(slot)
                else:
                    var slot = readByte()
                    frame.delete(int slot)
            of OpCode.Pop:
                self.lastPop = self.pop()
            of OpCode.JumpIfFalse:
                var offset = readShort()
                if isFalsey(self.peek(0)):
                    frame.ip += int offset
            of OpCode.Jump:
                var offset = readShort()
                frame.ip += int offset
            of OpCode.Loop:
                var offset = readShort()
                frame.ip -= int offset
            of OpCode.Call:
                var argCount = readByte()
                if not self.callValue(self.peek(int argCount), argCount):
                    return RUNTIME_ERROR
                frame = self.frames[self.frameCount - 1]
            of OpCode.Break:
                discard
            of OpCode.Return:
                var retResult = self.pop()
                if repl:
                    if not self.lastPop.isNil() and self.frameCount == 1:   # This is to avoid
                        # useless output with recursive calls
                        echo stringify(self.lastPop)
                        self.lastPop = asNil()
                self.frameCount -= 1
                discard self.frames.pop()
                if self.frameCount == 0:
                    discard self.pop()
                    return OK
                self.push(retResult)
                self.stackTop = len(frame.getView()) - 1 # TODO
                frame = self.frames[self.frameCount - 1]


proc freeObject(obj: ptr Obj) =
    ## Frees the associated memory
    ## of an object
    case obj.kind:
        of ObjectType.Function:
            var fun = cast[ptr Function](obj)
            when DEBUG_TRACE_ALLOCATION:
                echo &"DEBUG: Freeing function object with value '{stringify(fun)}'"
            fun.chunk.freeChunk()
            discard free(ObjectType.Function, fun)
        of ObjectType.String:
            var str = cast[ptr String](obj)
            when DEBUG_TRACE_ALLOCATION:
                echo &"DEBUG: Freeing string object with value '{stringify(str)}' of length {str.len}"
            discard freeArray(char, str.str, str.len)
            discard free(ObjectType.String, obj)
        else:
            discard


proc freeObjects(self: var VM) =
    ## Fress all the allocated objects
    ## from the VM
    var objCount = len(self.objects)
    for obj in reversed(self.objects):
        freeObject(obj)
        discard self.objects.pop()
    when DEBUG_TRACE_ALLOCATION:
        echo &"DEBUG: Freed {objCount} objects"


proc freeVM*(self: var VM) =
    ## Tears down the VM
    when DEBUG_TRACE_ALLOCATION:
        echo "\nDEBUG: Freeing all allocated memory before exiting"
    unsetControlCHook()
    try:
        self.freeObjects()
    except NilAccessError:
        stderr.write("A fatal error occurred -> could not free memory, segmentation fault\n")
        quit(71)


proc initVM*(): VM =
    ## Initializes the VM
    setControlCHook(handleInterrupt)
    var globals: Table[string, ptr Obj] = initTable[string, ptr Obj]()
    result = VM(lastPop: asNil(), objects: @[], globals: globals, source: "", file: "")


proc interpret*(self: var VM, source: string, repl: bool = false, file: string): InterpretResult =
    ## Interprets a source string containing JAPL code
    self.resetStack()
    var compiler = initCompiler(SCRIPT, file=file)
    var compiled = compiler.compile(source)
    self.source = source
    self.file = file
    self.objects = compiler.objects # TODO:
    # revisit the best way to transfer marked objects from the compiler
    # to the vm
    if compiled == nil:
        return COMPILE_ERROR
    self.push(compiled)
    discard self.callValue(compiled, 0)
    when DEBUG_TRACE_VM:
        echo "==== VM debugger starts ====\n"
    try:
        result = self.run(repl)
    except KeyboardInterrupt:
        self.error(newInterruptedError(""))
        return RUNTIME_ERROR
    when DEBUG_TRACE_VM:
        echo "==== VM debugger ends ====\n"
