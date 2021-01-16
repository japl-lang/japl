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
{.experimental: "implicitDeref".}

## Standard library imports
import algorithm
import strformat
import tables
import std/enumerate
## Our modules
import stdlib
import memory
import config
import compiler
import meta/opcode
import meta/frame
import types/baseObject
import types/japlString
import types/japlNil
import types/exception
import types/numbers
import types/boolean
import types/methods
import types/typeutils
import types/function
import types/native
# We always import it to
# avoid the compiler complaining
# about functions not existing
# in production builds
import util/debug


type
    KeyboardInterrupt* = object of CatchableError
    ## Custom exception to handle Ctrl+C
    InterpretResult = enum
        ## All possible interpretation results
        Ok,
        CompileError,
        RuntimeError
    VM* = ref object
        ## A wrapper around the virtual machine
        ## functionality
        lastPop*: ptr Obj
        frameCount*: int
        source*: string
        frames*: seq[CallFrame]
        stack*: ref seq[ptr Obj]
        stackTop*: int
        objects*: seq[ptr Obj]
        globals*: Table[string, ptr Obj]
        cached: array[6, ptr Obj]
        file*: string


func handleInterrupt() {.noconv.} =
    ## Raises an appropriate exception
    ## to let us catch and handle
    ## Ctrl+C gracefully
    raise newException(KeyboardInterrupt, "Ctrl+C")


proc resetStack*(self: VM) =
    ## Resets the VM stack to a blank state
    self.stack = new(seq[ptr Obj])
    self.frames = @[]
    self.frameCount = 0
    self.stackTop = 0


proc getBoolean(self: VM, kind: bool): ptr Obj =
    ## Tiny little optimization for booleans
    ## which are pre-allocated on startup
    if kind:
        return self.cached[0]
    else:
        return self.cached[1]


proc error*(self: VM, error: ptr JAPLException) =
    ## Reports runtime errors with a nice traceback

    # TODO: Once we have proper exceptions,
    # this procedure will be used to report
    # those that were not catched and managed
    # to climb the call stack to the first
    # frame (the global code object)

    # Exceptions are objects too and they need to
    # be freed like any other entity in JAPL
    self.objects.add(error)   # TODO -> Move this somewhere else to mark exceptions even before they are raised
    var previous = ""  # All this stuff seems overkill, but it makes the traceback look nicer
    var repCount = 0   # and if we are here we are far beyond a point where performance matters anyway
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


proc pop*(self: VM): ptr Obj =
    ## Pops an object off the stack
    result = self.stack.pop()
    self.stackTop -= 1


proc push*(self: VM, obj: ptr Obj) =
    ## Pushes an object onto the stack
    self.stack.add(obj)
    if obj notin self.objects and obj notin self.cached:
        self.objects.add(obj)
    self.stackTop += 1


proc push*(self: VM, ret: returnType) =
    ## Pushes a return value from a builtin
    ## method onto the stack and handles errors
    case ret.kind:
        of returnTypes.Object:
            self.push(ret.result)
        of returnTypes.Exception:
            self.error(cast[ptr JAPLException](ret.result))
        of returnTypes.True:
            self.push(self.cached[0])
        of returnTypes.False:
            self.push(self.cached[1])
        of returnTypes.Nil:
            self.push(self.cached[2])
        of returnTypes.Inf:
            self.push(self.cached[3])
        of returnTypes.nInf:
            self.push(self.cached[4])
        of returnTypes.NotANumber:
            self.push(self.cached[5])


proc peek*(self: VM, distance: int): ptr Obj =
    ## Peeks an object (at a given distance from the
    ## current index) from the stack
    return self.stack[self.stackTop - distance - 1]


proc call(self: VM, function: ptr Function, argCount: int): bool =
    ## Sets up the call frame and performs error checking
    ## when calling callables
    if argCount != function.arity:
        self.error(newTypeError(&"function '{stringify(function.name)}' takes {function.arity} argument(s), got {argCount}"))
        return false
    if self.frameCount == FRAMES_MAX:
        self.error(newRecursionError("max recursion depth exceeded"))
        return false
    let slot = self.stack.high() - argCount
    var frame = CallFrame(function: function, ip: 0, slot: slot, stack: self.stack)   # TODO: 
    # Check why this raises NilAccessError when high recursion limit is hit
    self.frames.add(frame)
    self.frameCount += 1
    return true


proc call(self: VM, native: ptr Native, argCount: int): bool =
    ## Does the same as self.call, but with native functions
    if argCount != native.arity and native.arity != -1:
        self.error(newTypeError(&"function '{stringify(native.name)}' takes {native.arity} argument(s), got {argCount}"))
        return false
    let slot = self.stack.high() - argCount + 1
    var args: seq[ptr Obj]
    for i in countup(slot, self.stack.high()):
        args.add(self.stack[i])
    let nativeResult = native.nimproc(args)
    for i in countup(slot - 1, self.stack.high()):
        discard self.pop() # TODO once stack is a custom datatype,
        # just reduce its length
    case nativeResult.kind:
        of retNative.True:
            self.push(self.getBoolean(true))
        of retNative.False:
            self.push(self.getBoolean(false))
        of retNative.Object:
            self.push(nativeResult.result)
        of retNative.Nil:
            self.push(self.cached[2])
        of retNative.Inf:
            self.push(self.cached[3])
        of retNative.nInf:
            self.push(self.cached[4])
        of retNative.NotANumber:
            self.push(self.cached[5])
        of retNative.Exception:
            self.error(cast[ptr JaplException](nativeResult.result))
            return false
    return true


proc callObject(self: VM, callee: ptr Obj, argCount: uint8): bool =
    ## Wrapper around call() to do type checking
    if callee.isCallable():
        case callee.kind:
            of ObjectType.Function:
                return self.call(cast[ptr Function](callee), int(argCount))
            of ObjectType.Native:
                return self.call(cast[ptr Native](callee), int(argCount))
            else:   # TODO: Classes
                discard  # Unreachable
    else:
        self.error(newTypeError(&"object of type '{callee.typeName()}' is not callable"))
        return false


proc defineGlobal*(self: VM, name: string, value: ptr Obj) =
    ## Adds a key-value couple to the VM's global scope
    self.globals[name] = value


proc readByte(self: CallFrame): uint8 =
    ## Reads a single byte from the given
    ## frame's chunk of bytecode
    inc(self.ip)
    result = self.function.chunk.code[self.ip - 1]


proc readBytes(self: CallFrame): int =
    ## Reads and decodes 3 bytes from the
    ## given frame's chunk into an integer
    var arr = [self.readByte(), self.readByte(), self.readByte()]
    copyMem(result.addr, unsafeAddr(arr), sizeof(arr))


proc readShort(self: CallFrame): uint16 =
    ## Reads a 16 bit number from the
    ## given frame's chunk
    let arr = [self.readByte(), self.readByte()]
    copyMem(result.addr, unsafeAddr(arr), sizeof(uint16))


proc readConstant(self: CallFrame): ptr Obj =
    ## Reads a constant from the given
    ## frame's constant table
    var arr = [self.readByte(), self.readByte(), self.readByte()]
    var idx: int
    copyMem(idx.addr, arr.addr, sizeof(arr))
    result = self.function.chunk.consts[idx]



proc showRuntime*(self: VM, frame: CallFrame, iteration: uint64) = 
    ## Shows debug information about the current
    ## state of the virtual machine
    stdout.write(&"Iteration N. {iteration}\nCurrent VM stack status: [")
    for i, v in self.stack:
        stdout.write(stringify(v))
        if i < self.stack.high():
            stdout.write(", ")
    stdout.write("]\nCurrent global scope status: {")
    for i, (k, v) in enumerate(self.globals.pairs()):
        stdout.write(&"'{k}': {stringify(v)}")
        if i < self.globals.len() - 1:
            stdout.write(", ")
    stdout.write("}\nCurrent frame type: ")
    if frame.function.name == nil:
        stdout.write("main\n")
    else:
        stdout.write(&"function, '{frame.function.name.stringify()}'\n")
    echo &"Current frame count: {self.frameCount}"
    echo &"Current frame length: {frame.len}"
    stdout.write("Current frame constants table: ")
    stdout.write("[")
    for i, e in frame.function.chunk.consts:
        stdout.write(stringify(e))
        if i < frame.function.chunk.consts.high():
            stdout.write(", ")
    stdout.write("]\nCurrent frame stack status: ")
    stdout.write("[")
    for i, e in frame.getView():
        stdout.write(stringify(e))
        if i < len(frame) - 1:
            stdout.write(", ")
    stdout.write("]\n")
    discard disassembleInstruction(frame.function.chunk, frame.ip - 1)


proc run(self: VM, repl: bool): InterpretResult =
    ## Chews trough bytecode instructions executing
    ## them one at a time: this is the runtime's
    ## main loop
    var frame = self.frames[self.frameCount - 1]
    when DEBUG_TRACE_VM:
        var iteration: uint64 = 0
    while true:
        {.computedgoto.}   # See https://nim-lang.org/docs/manual.html#pragmas-computedgoto-pragma
        when DEBUG_TRACE_VM:    # Insight inside the VM
            iteration += 1
            self.showRuntime(frame, iteration)
        case OpCode(frame.readByte()):   # Main OpCodes dispatcher
            of OpCode.Constant:
                # Loads a constant from the chunk's constant
                # table
                self.push(frame.readConstant())
            of OpCode.Negate:
                # Performs unary negation
                let operand = self.pop()
                try:
                    self.push(operand.negate())
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported unary operator '-' for object of type '{operand.typeName()}'"))
                    return RuntimeError
            of OpCode.Shl:
                # Bitwise left-shift
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.binaryShl(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '<<' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Shr:
                # Bitwise right-shift
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.binaryShr(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '>>' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Xor:
                # Bitwise xor
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.binaryXor(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '^' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Bor:
                # Bitwise or
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.binaryOr(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '&' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Bnot:
                # Bitwise not
                var operand = self.pop()
                try:
                    self.push(operand.binaryNot())
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported unary operator '~' for object of type '{operand.typeName()}'"))
                    return RuntimeError
            of OpCode.Band:
                # Bitwise and
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.binaryAnd(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '&' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Add:
                # Binary +
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.sum(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '+' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Subtract:
                # Binary -
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.sub(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '-' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Divide:
                # Binary /
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.trueDiv(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '/' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Multiply:
                # Binary *
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.mul(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '*' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Mod:
                # Binary % (modulo division)
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.divMod(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '%' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Pow:
                # Binary ** (exponentiation)
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.pow(right))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '**' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.True:
                ## TODO: Make sure that even operations that can yield
                ## preallocated types, but do not have access to the VM,
                ## yield these cached types
                self.push(cast[ptr Bool](self.getBoolean(true)))
            of OpCode.False:
                self.push(cast[ptr Bool](self.getBoolean(false)))
            of OpCode.Nil:
                self.push(cast[ptr Nil](self.cached[2]))
            of OpCode.Nan:
                self.push(cast[ptr NotANumber](self.cached[4]))
            of OpCode.Inf:
                self.push(cast[ptr Infinity](self.cached[3]))
            of OpCode.Not:
                self.push(self.getBoolean(self.pop().isFalsey()))
            of OpCode.Equal:
                # Compares object equality
                # Here order doesn't matter, because if a == b
                # then b == a (at least in *most* languages, sigh)
                self.push(self.getBoolean(self.pop().eq(self.pop())))
                # Doesn't this chain of calls look beautifully
                # intuitive?
            of OpCode.Less:
                # Binary less (<)
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(self.getBoolean(left.lt(right)))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '<' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Greater:
                # Binary greater (>)
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(self.getBoolean(left.gt(right)))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '>' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Is:
                # Implements object identity (i.e. same pointer)
                # This is implemented internally for obvious
                # reasons and works on any pair of objects
                var right = self.pop()
                var left = self.pop()
                self.push(self.getBoolean(left == right))
            of OpCode.As:
                # Implements type casting (TODO: Only allow classes)
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(objAs(left, right.kind))
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator 'as' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.GetItem:
                # Implements expressions such as a[b]
                # TODO: More generic method
                var right = self.pop()
                var left = self.pop()
                try:
                    self.push(left.getItem(right))
                except NotImplementedError:
                    self.error(newTypeError(&"object of type '{left.typeName()}' does not support getItem expressions"))
                    return RuntimeError
            of OpCode.Slice:
                # Implements expressions such as a[b:c]
                var right = self.pop()
                var left = self.pop()
                var operand = self.pop()
                try:
                    self.push(operand.Slice(right, left))
                except NotImplementedError:
                    self.error(newTypeError(&"object of type '{operand.typeName()}' does not support slicing"))
                    return RuntimeError
            of OpCode.DefineGlobal:
                # Defines a global variable
                var name = frame.readConstant().toStr()
                self.globals[name] = self.peek(0)
                discard self.pop()
            of OpCode.GetGlobal:
                # Retrieves a global variable
                var constant = frame.readConstant().toStr()
                if constant notin self.globals:
                    self.error(newReferenceError(&"undefined name '{constant}'"))
                    return RuntimeError
                else:
                    self.push(self.globals[constant])
            of OpCode.SetGlobal:
                # Changes the value of an already defined global variable
                var constant = frame.readConstant().toStr()
                if constant notin self.globals:
                    self.error(newReferenceError(&"assignment to undeclared name '{constant}'"))
                    return RuntimeError
                else:
                    self.globals[constant] = self.peek(0)
            of OpCode.DeleteGlobal:
                # Deletes a global variable
                # TODO: Inspect potential issues with the GC
                var constant = frame.readConstant().toStr()
                if constant notin self.globals:
                    self.error(newReferenceError(&"undefined name '{constant}'"))
                    return RuntimeError
                else:
                    self.globals.del(constant)
            of OpCode.GetLocal:
                # Retrieves a local variable
                self.push(frame[frame.readBytes()])
            of OpCode.SetLocal:
                # Changes the value of an already defined local variable
                frame[frame.readBytes()] = self.peek(0)
            of OpCode.DeleteLocal:
                # Deletes a global variable
                # TODO: Inspect potential issues with the GC
                frame.delete(frame.readBytes())
            of OpCode.Pop:
                # Pops an item off the stack
                self.lastPop = self.pop()
            of OpCode.JumpIfFalse:
                # Skips a certain amount of
                # bytecode instructions
                # if the object at the top of
                # our stack is falsey
                let jmpOffset = int frame.readShort()
                if isFalsey(self.peek(0)):
                    frame.ip += int jmpOffset
            of OpCode.Jump:
                # Jumps a certain amount of bytecode
                # instructions, unconditionally
                frame.ip += int frame.readShort()
            of OpCode.Loop:
                # Loops back a certain amount of
                # bytecode instructions, unconditionally
                frame.ip -= int frame.readShort()
            of OpCode.Call:
                # Implements functions call
                var argCount = frame.readByte()
                if not self.callObject(self.peek(int argCount), argCount):
                    return RuntimeError
                frame = self.frames[self.frameCount - 1]
            of OpCode.Break:
                discard   # Unused (the compiler converts it to other stuff before it arrives here)
            of OpCode.Return:
                # Handles returning values from the callee to the caller
                # and sets up the stack to proceed with execution
                var retResult = self.pop()
                if repl and not self.lastPop.isNil() and self.frameCount == 1:
                    # TODO -> Make this more efficient (move into japl.nim?)
                    # Prints the last expression to stdout as long as we're
                    # in REPL mode, the expression isn't nil and we're at the
                    # top-level code
                    echo stringify(self.lastPop)
                    self.lastPop = cast[ptr Nil](self.cached[2])
                self.frameCount -= 1
                discard self.frames.pop()
                if self.frameCount == 0:
                    discard self.pop()
                    return OK
                self.stackTop -= frame.clear()
                self.push(retResult)
                frame = self.frames[self.frameCount - 1]


proc freeObject(self: VM, obj: ptr Obj) =
    ## Frees the associated memory
    ## of an object
    case obj.kind:
        of ObjectType.String:
            var str = cast[ptr String](obj)
            when DEBUG_TRACE_ALLOCATION:
                echo &"DEBUG - VM: Freeing string object of length {str.len}"
            discard freeArray(char, str.str, str.len)
            discard free(ObjectType.String, obj)
        of ObjectType.Exception, ObjectType.Class,
           ObjectType.Module, ObjectType.BaseObject, ObjectType.Integer,
           ObjectType.Float, ObjectType.Bool, ObjectType.NotANumber, 
           ObjectType.Infinity, ObjectType.Nil, ObjectType.Native:
               when DEBUG_TRACE_ALLOCATION:
                    if obj notin self.cached:
                        echo &"DEBUG- VM: Freeing {obj.typeName()} object with value '{stringify(obj)}'"
                    else:
                        echo &"DEBUG - VM: Freeing cached {obj.typeName()} object with value '{stringify(obj)}'"
               discard free(obj.kind, obj)
        of ObjectType.Function:
            var fun = cast[ptr Function](obj)
            when DEBUG_TRACE_ALLOCATION:
                if fun.name == nil:
                    echo &"DEBUG - VM: Freeing global code object"
                else:
                    echo &"DEBUG - VM: Freeing function object with name '{stringify(fun)}'"
            fun.chunk.freeChunk()
            discard free(ObjectType.Function, fun)


proc freeObjects(self: VM) =
    ## Frees all the allocated objects
    ## from the VM
    when DEBUG_TRACE_ALLOCATION:
        var runtimeObjCount = len(self.objects)
        var cacheCount = len(self.cached)
        var runtimeFreed = 0
        var cachedFreed = 0
    for obj in reversed(self.objects):
        self.freeObject(obj)
        discard self.objects.pop()
        when DEBUG_TRACE_ALLOCATION:
            runtimeFreed += 1
    for cached_obj in self.cached:
        self.freeObject(cached_obj)
        when DEBUG_TRACE_ALLOCATION:
            cachedFreed += 1
    when DEBUG_TRACE_ALLOCATION:
        echo &"DEBUG - VM: Freed {runtimeFreed + cachedFreed} objects out of {runtimeObjCount + cacheCount} ({cachedFreed}/{cacheCount} cached objects, {runtimeFreed}/{runtimeObjCount} runtime objects)"


proc freeVM*(self: VM) =
    ## Tears down the VM
    unsetControlCHook()
    try:
        self.freeObjects()
    except NilAccessDefect:
        stderr.write("A fatal error occurred -> could not free memory, segmentation fault\n")
        quit(71)
    when DEBUG_TRACE_ALLOCATION:
        if self.objects.len > 0:
            echo &"DEBUG - VM: Warning, {self.objects.len} objects were not freed"


proc initCache(self: VM) = 
    ## Initializes the static cache for singletons
    ## such as true and false

    # TODO -> Make sure that every operation
    # concerning singletons ALWAYS returns
    # these cached objects in order to 
    # implement proper object identity
    # in a quicker way than it is done
    # for equality
    self.cached = 
            [
            true.asBool().asObj(),
            false.asBool().asObj(),
            asNil().asObj(),
            asInf().asObj(),
            nil,
            asNan().asObj()
            ]
    # We cache -inf as well
    let nInf = asInf()
    nInf.isNegative = true
    self.cached[4] = nInf.asObj()


proc stdlibInit*(vm: VM) =
    ## Initializes the VM's standard library by defining builtin
    ## functions that do not require imports. An arity of -1
    ## means that the function is variadic (or that it can
    ## take a different number of arguments according to
    ## how it's called) and should be handled by the nim
    ## procedure accordingly
    vm.defineGlobal("print", newNative("print", natPrint, -1))
    vm.defineGlobal("clock", newNative("clock", natClock, 0))
    vm.defineGlobal("round", newNative("round", natRound, -1))
    vm.defineGlobal("toInt", newNative("toInt", natToInt, 1))
    vm.defineGlobal("toString", newNative("toString", natToString, 1))
    vm.defineGlobal("type", newNative("type", natType, 1))


proc initVM*(): VM =
    ## Initializes the Virtual Machine by
    ## creating the cache, setting signal
    ## handlers, loading the standard
    ## library and preparing the stack
    ## and internal data structures
    result = VM(objects: @[], globals: initTable[string, ptr Obj](), source: "", file: "")
    result.initCache()
    result.stdlibInit()
    result.resetStack()
    setControlCHook(handleInterrupt)
    result.lastPop = cast[ptr Nil](result.cached[2])




proc interpret*(self: VM, source: string, repl: bool = false, file: string): InterpretResult =
    ## Interprets a source string containing JAPL code
    self.resetStack()
    self.source = source
    self.file = file
    var compiler = initCompiler(SCRIPT, file=file)
    var compiled = compiler.compile(source)
    # Here we take into account that self.interpret() might
    # get called multiple times (like in the REPL) and we don't wanna loose
    # what we allocated before, so we merge everything we already
    # allocated and everything the compiler allocated at compile time
    self.objects = self.objects & compiler.objects
    # TODO: revisit the best way to transfer marked objects from the compiler to the vm
    if compiled == nil:
        # Compile-time error
        compiler.freeCompiler()
        return CompileError
    # Since in JAPL all code runs in some
    # sort of function, we push our global
    # "code object" and call it like any
    # other function
    self.push(compiled)
    discard self.callObject(compiled, 0)
    when DEBUG_TRACE_VM:
        echo "==== VM debugger starts ====\n"
    try:
        result = self.run(repl)
    except KeyboardInterrupt:   # TODO: Better handling
        self.error(newInterruptedError(""))
        return RuntimeError
    when DEBUG_TRACE_VM:
        echo "==== VM debugger ends ====\n"
