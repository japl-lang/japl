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
import strformat
import tables
import std/enumerate
## Our modules
import config
when not SKIP_STDLIB_INIT:
    import stdlib
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
import types/arraylist
# We always import it to
# avoid the compiler complaining
# about functions not existing
# in production builds
import util/debug

when DEBUG_TRACE_VM:
  import terminal


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
        ## functionality. Using custom heap allocated
        ## types for everything might sound excessive,
        ## but bad things happen when nim's GC puts its
        ## hands on JAPL-owned objects, so it was decided
        ## to reduce the GC's impact to a minimal
        lastPop*: ptr Obj
        source*: ptr String
        frames*: ptr ArrayList[CallFrame]
        stack*: ptr ArrayList[ptr Obj]
        objects*: ptr ArrayList[ptr Obj]
        globals*: Table[string, ptr Obj]   # TODO: Custom hashmap
        cached*: array[6, ptr Obj]
        file*: ptr String


func handleInterrupt() {.noconv.} =
    ## Raises an appropriate exception
    ## to let us catch and handle
    ## Ctrl+C gracefully
    raise newException(KeyboardInterrupt, "Ctrl+C")


proc initStack*(self: VM) =
    ## Initializes the VM's stack, frame stack
    ## and objects arraylist
    when DEBUG_TRACE_VM:
        echo "DEBUG - VM: Resetting the stack"
    self.stack = newArrayList[ptr Obj]()
    self.objects = newArrayList[ptr Obj]()
    self.frames = newArrayList[CallFrame]()


proc resetStack*(self: VM) = 
    ## Resets the VM's stack to a blank state
    while self.stack.len() >= 1:
        discard self.stack.pop()
    while self.frames.len() >= 1:
        discard self.frames.pop()


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
    self.objects.append(error)   # TODO -> Move this somewhere else to mark exceptions even before they are raised
    var previous = ""  # All this stuff seems overkill, but it makes the traceback look nicer
    var repCount = 0   # and if we are here we are far beyond a point where performance matters anyway
    var mainReached = false
    var output = ""
    stderr.write("An unhandled exception occurred, traceback below:\n")
    for frame in reversed(self.frames):
        if mainReached:
            break
        var function = frame.function
        var line = function.chunk.lines[frame.ip]
        if function.name == nil:
            output = &"  File '{self.file}', line {line}, in <module>:"
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


proc push*(self: VM, obj: ptr Obj) =
    ## Pushes an object onto the stack
    self.stack.append(obj)
    if obj notin self.objects and obj notin self.cached:
        self.objects.append(obj)


proc push*(self: VM, ret: returnType): bool =
    ## Pushes a return value from a builtin
    ## method onto the stack and handles errors
    result = true
    case ret.kind:
        of returnTypes.Object:
            self.push(ret.result)
        of returnTypes.Exception:
            self.error(cast[ptr JAPLException](ret.result))
            result = false
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
    return self.stack[self.stack.high() - distance]


proc call(self: VM, function: ptr Function, argCount: int): bool =
    ## Sets up the call frame and performs error checking
    ## when calling callables
    if argCount < function.arity:
        var arg: string
        if function.arity > 1:
            arg = "s"
        self.error(newTypeError(&"function '{stringify(function.name)}' takes at least {function.arity} argument{arg}, got {argCount}"))
        return false
    elif argCount > function.arity and (argCount - function.arity) - function.optionals != 0:
        self.error(newTypeError(&"function '{stringify(function.name)}' takes at least {function.arity} arguments and at most {function.arity + function.optionals}, got {argCount}"))
        return false
    if self.frames.len() == FRAMES_MAX:
        self.error(newRecursionError("max recursion depth exceeded"))
        return false
    let slot = self.stack.high() - argCount
    var frame = CallFrame(function: function, ip: 0, slot: slot, stack: self.stack)
    self.frames.append(frame)
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



when DEBUG_TRACE_VM:
    proc showRuntime*(self: VM, frame: CallFrame, iteration: uint64) = 
        ## Shows debug information about the current
        ## state of the virtual machine

        let view = frame.getView()
        setForegroundColor(fgYellow)
        stdout.write("DEBUG - VM: General information\n")
        stdout.write(&"DEBUG - VM:\tIteration -> {iteration}\n")
        setForegroundColor(fgDefault)
        stdout.write("DEBUG - VM:\tStack -> [")
        for i, v in self.stack:
            stdout.write(stringify(v))
            if i < self.stack.high():
                stdout.write(", ")
        stdout.write("]\nDEBUG - VM: \tGlobals -> {")
        for i, (k, v) in enumerate(self.globals.pairs()):
            stdout.write(&"'{k}': {stringify(v)}")
            if i < self.globals.len() - 1:
                stdout.write(", ")
        stdout.write("}\nDEBUG - VM: Frame information\n")
        stdout.write("DEBUG - VM:\tType -> ")
        if frame.function.name == nil:
            stdout.write("main\n")
        else:
            stdout.write(&"function, '{frame.function.name.stringify()}'\n")
        echo &"DEBUG - VM:\tCount -> {self.frames.len()}"
        echo &"DEBUG - VM:\tLength -> {view.len}"
        stdout.write("DEBUG - VM:\tTable -> ")
        stdout.write("[")
        for i, e in frame.function.chunk.consts:
            stdout.write(stringify(e))
            if i < len(frame.function.chunk.consts) - 1:
                stdout.write(", ")
        stdout.write("]\nDEBUG - VM:\tStack view -> ")
        stdout.write("[")
        for i, e in view:
            stdout.write(stringify(e))
            if i < len(view) - 1:
                stdout.write(", ")
        stdout.write("]\n")
        echo "DEBUG - VM: Current instruction"
        discard disassembleInstruction(frame.function.chunk, frame.ip - 1)


proc run(self: VM): InterpretResult =
    ## Chews trough bytecode instructions executing
    ## them one at a time: this is the runtime's
    ## main loop
    var frame = self.frames[self.frames.high()]
    var instruction: OpCode
    when DEBUG_TRACE_VM:
        var iteration: uint64 = 0
    while true:
        instruction =  OpCode(frame.readByte())
        {.computedgoto.}   # See https://nim-lang.org/docs/manual.html#pragmas-computedgoto-pragma
        when DEBUG_TRACE_VM:    # Insight inside the VM
            iteration += 1
            self.showRuntime(frame, iteration)
        case instruction:   # Main OpCodes dispatcher
            of OpCode.Constant:
                # Loads a constant from the chunk's constant
                # table
                self.push(frame.readConstant())
            of OpCode.Negate:
                # Performs unary negation
                let operand = self.pop()
                try:
                    if not self.push(operand.negate()):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported unary operator '-' for object of type '{operand.typeName()}'"))
                    return RuntimeError
            of OpCode.Shl:
                # Bitwise left-shift
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.binaryShl(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '<<' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Shr:
                # Bitwise right-shift
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.binaryShr(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '>>' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Xor:
                # Bitwise xor
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.binaryXor(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '^' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Bor:
                # Bitwise or
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.binaryOr(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '&' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Bnot:
                # Bitwise not
                var operand = self.pop()
                try:
                    if not self.push(operand.binaryNot()):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported unary operator '~' for object of type '{operand.typeName()}'"))
                    return RuntimeError
            of OpCode.Band:
                # Bitwise and
                var right = self.pop()
                var left = self.pop()
                try:
                   if not self.push(left.binaryAnd(right)):
                       return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '&' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Add:
                # Binary +
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.sum(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '+' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Subtract:
                # Binary -
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.sub(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '-' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Divide:
                # Binary /
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.trueDiv(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '/' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Multiply:
                # Binary *
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.mul(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '*' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Mod:
                # Binary % (modulo division)
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.divMod(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '%' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Pow:
                # Binary ** (exponentiation)
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.pow(right)):
                        return RuntimeError
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
                var comp: tuple[result: bool, obj: ptr Obj]
                try:
                    comp = left.lt(right)
                    if system.`==`(comp.obj, nil):
                        self.push(self.getBoolean(comp.result))
                    else:
                        self.push(comp.obj)
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '<' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Greater:
                # Binary greater (>)
                var right = self.pop()
                var left = self.pop()
                var comp: tuple[result: bool, obj: ptr Obj]
                try:
                    comp = left.gt(right)
                    if system.`==`(comp.obj, nil):
                        self.push(self.getBoolean(comp.result))
                    else:
                        self.push(comp.obj)
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '>' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.LessOrEqual:
                var right = self.pop()
                var left = self.pop()
                var comp: tuple[result: bool, obj: ptr Obj]
                try:
                    comp = left.lt(right)
                    if not comp.result and left == right:
                        comp.result = true
                    if system.`==`(comp.obj, nil):
                        self.push(self.getBoolean(comp.result))
                    else:
                        self.push(comp.obj)
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '<' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.GreaterOrEqual:
                var right = self.pop()
                var left = self.pop()
                var comp: tuple[result: bool, obj: ptr Obj]
                try:
                    comp = left.gt(right)
                    if not comp.result and left == right:
                        comp.result = true
                    if system.`==`(comp.obj, nil):
                        self.push(self.getBoolean(comp.result))
                    else:
                        self.push(comp.obj)
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator '>' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.Is:
                # Implements object identity (i.e. same pointer)
                # This is implemented internally for obvious
                # reasons and works on any pair of objects, which
                # is why we call nim's system.== operator and NOT
                # our custom one
                var right = self.pop()
                var left = self.pop()
                self.push(self.getBoolean(system.`==`(left, right)))
            of OpCode.As:
                # Implements type casting (TODO: Only allow classes)
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(objAs(left, right.kind)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"unsupported binary operator 'as' for objects of type '{left.typeName()}' and '{right.typeName()}'"))
                    return RuntimeError
            of OpCode.GetItem:
                # Implements expressions such as a[b]
                # TODO: More generic method
                var right = self.pop()
                var left = self.pop()
                try:
                    if not self.push(left.getItem(right)):
                        return RuntimeError
                except NotImplementedError:
                    self.error(newTypeError(&"object of type '{left.typeName()}' does not support getItem expressions"))
                    return RuntimeError
            of OpCode.Slice:
                # Implements expressions such as a[b:c]
                var right = self.pop()
                var left = self.pop()
                var operand = self.pop()
                try:
                    if not self.push(operand.Slice(right, left)):
                        return RuntimeError
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
                frame = self.frames[self.frames.high()]
            of OpCode.Break:
                discard   # Unused (the compiler converts it to other stuff before it arrives here)
            of OpCode.Return:
                # Handles returning values from the callee to the caller
                # and sets up the stack to proceed with execution
                var retResult = self.pop()
                # Pops the function's frame
                discard self.frames.pop()
                if self.frames.len() == 0:
                    discard self.pop()
                    return OK
                discard frame.clear()
                self.push(retResult)
                frame = self.frames[self.frames.high()]


proc freeObjects(self: VM) =
    ## Frees all the allocated objects
    ## from the VM
    when DEBUG_TRACE_ALLOCATION:
        var runtimeObjCount = len(self.objects)
        var cacheCount = len(self.cached)
        var runtimeFreed = 0
        var cachedFreed = 0
    for obj in reversed(self.objects):
        freeObject(obj)
        discard self.objects.pop()
        when DEBUG_TRACE_ALLOCATION:
            runtimeFreed += 1
    for cached_obj in self.cached:
        freeObject(cached_obj)
        when DEBUG_TRACE_ALLOCATION:
            cachedFreed += 1
    when DEBUG_TRACE_ALLOCATION:
        echo &"DEBUG - VM: Freed {runtimeFreed + cachedFreed} objects out of {runtimeObjCount + cacheCount} ({cachedFreed}/{cacheCount} cached objects, {runtimeFreed}/{runtimeObjCount} runtime objects)"


proc freeVM*(self: VM) =
    ## Tears down the VM
    unsetControlCHook()
    try:
        self.freeObjects()
        freeObject(self.objects)
        freeObject(self.stack)
        freeObject(self.frames)
    except NilAccessDefect:
        stderr.write("A fatal error occurred -> could not free memory, segmentation fault\n")
        quit(71)
    when DEBUG_TRACE_ALLOCATION:
        if self.objects.len > 0:
            echo &"DEBUG - VM: Warning, {self.objects.len} objects were not freed"
        echo "DEBUG - VM: The virtual machine has shut down"
    


proc initCache(self: VM) = 
    ## Initializes the static cache for singletons
    ## such as true and false

    # TODO -> Make sure that every operation
    # concerning singletons ALWAYS returns
    # these cached objects in order to 
    # implement proper object identity
    # in a quicker way than it is done
    # for equality
    when DEBUG_TRACE_VM:
        echo "DEBUG - VM: Initializing singletons cache"
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


proc initStdlib*(vm: VM) =
    ## Initializes the VM's standard library by defining builtin
    ## functions that do not require imports. An arity of -1
    ## means that the function is variadic (or that it can
    ## take a different number of arguments according to
    ## how it's called) and should be handled by the nim
    ## procedure accordingly
    when DEBUG_TRACE_VM and not SKIP_STDLIB_INIT or not DEBUG_TRACE_VM:
        when DEBUG_TRACE_VM:
            echo "DEBUG - VM: Initializing stdlib"
        vm.defineGlobal("print", newNative("print", natPrint, -1))
        vm.defineGlobal("printErr", newNative("printErr", natPrintErr, -1))
        vm.defineGlobal("clock", newNative("clock", natClock, 0))
        vm.defineGlobal("round", newNative("round", natRound, -1))
        vm.defineGlobal("toInt", newNative("toInt", natToInt, 1))
        vm.defineGlobal("toString", newNative("toString", natToString, 1))
        vm.defineGlobal("type", newNative("type", natType, 1))
        vm.defineGlobal("readLine", newNative("readLine", natReadline, -1))
    when DEBUG_TRACE_VM and SKIP_STDLIB_INIT:
        echo "DEBUG - VM: Skipping stdlib initialization"


proc initVM*(): VM =
    ## Initializes the Virtual Machine by
    ## creating the cache, setting signal
    ## handlers, loading the standard
    ## library and preparing the stack
    ## and internal data structures
    when DEBUG_TRACE_VM:
        echo &"DEBUG - VM: Initializing the virtual machine, {JAPL_VERSION_STRING}"
    result = VM(globals: initTable[string, ptr Obj]())
    result.initStack()
    result.initCache()
    result.initStdlib()
    setControlCHook(handleInterrupt)
    result.lastPop = cast[ptr Nil](result.cached[2])
    when DEBUG_TRACE_VM:
        echo &"DEBUG - VM: Initialization complete, compiled with the following constants: FRAMES_MAX={FRAMES_MAX}, ARRAY_GROW_FACTOR={ARRAY_GROW_FACTOR}, MAP_LOAD_FACTOR={MAP_LOAD_FACTOR}"



proc interpret*(self: VM, source: string, file: string): InterpretResult =
    ## Interprets a source string containing JAPL code
    when DEBUG_TRACE_VM:
        echo &"DEBUG - VM: Preparing to run '{file}'"
    self.resetStack()
    self.source = source.asStr()
    self.file = file.asStr()
    self.objects.append(self.source)
    self.objects.append(self.file)
    when DEBUG_TRACE_VM:
        echo &"DEBUG - VM: Compiling '{file}'"
    var compiler = initCompiler(SCRIPT, file=file)
    var compiled = compiler.compile(source)
    # Here we take into account that self.interpret() might
    # get called multiple times (like in the REPL) and we don't wanna loose
    # what we allocated before, so we merge everything we already
    # allocated and everything the compiler allocated at compile time
    self.objects.extend(compiler.objects)
    if compiled == nil:
        # Compile-time error
        compiler.freeCompiler()
        when DEBUG_TRACE_VM:
            echo "DEBUG - VM: Result -> CompileError"
        return CompileError
    when DEBUG_TRACE_VM:
        echo "DEBUG - VM: Compilation successful"
    # Since in JAPL all code runs in some
    # sort of function, we push our global
    # "code object" and call it like any
    # other function
    self.push(compiled)
    discard self.callObject(compiled, 0)
    try:
        result = self.run()
    except KeyboardInterrupt:   # TODO: Better handling
        self.error(newInterruptedError(""))
        when DEBUG_TRACE_VM:
            echo "DEBUG - VM: Result -> RuntimeError"
        return RuntimeError
    when DEBUG_TRACE_VM:
        echo &"DEBUG - VM: Result -> {result}"
