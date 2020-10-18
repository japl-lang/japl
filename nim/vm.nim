import algorithm
import strutils
import strformat
import math
import lenientops
import common
import compiler
import tables
import util/debug
import meta/chunk
import meta/valueobject
import types/exceptions
import types/objecttype
import types/stringtype
import types/functiontype
import bitops
import memory


proc `**`(a, b: int): int = pow(a.float, b.float).int


proc `**`(a, b: float): float = pow(a, b)


type
    KeyboardInterrupt* = object of CatchableError

    InterpretResult = enum
        OK,
        COMPILE_ERROR,
        RUNTIME_ERROR


func handleInterrupt() {.noconv.} =
    raise newException(KeyboardInterrupt, "Ctrl+C")


proc resetStack*(self: var VM) =
    self.stack = @[]
    self.frames = @[]
    self.frameCount = 0
    self.stackTop = 0



proc error*(self: var VM, error: ptr JAPLException) =
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


proc pop*(self: var VM): Value =
    result = self.stack.pop()
    self.stackTop -= 1


proc push*(self: var VM, value: Value) =
    self.stack.add(value)
    self.stackTop += 1


proc peek*(self: var VM, distance: int): Value =
    return self.stack[self.stackTop - distance - 1]


template addObject*(self: ptr VM, obj: untyped): untyped =
    self.objects.add(obj)
    obj


proc slice(self: var VM): bool =
    var idx = self.pop()
    var peeked = self.pop()
    case peeked.kind:
        of OBJECT:
            case peeked.obj.kind:
                of ObjectType.String:
                    var str = peeked.toStr()
                    if not idx.isInt():
                        self.error(newTypeError("string indeces must be integers"))
                        return false
                    elif idx.toInt() < 0:
                        idx.intValue = len(str) + idx.toInt()
                        if idx.toInt() < 0:
                            self.error(newIndexError("string index out of bounds"))
                            return false
                    if idx.toInt() - 1 > len(str) - 1:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    self.push(Value(kind: OBJECT, obj: addObject(addr self, newString(&"{str[idx.toInt()]}"))))
                    return true

                else:
                    self.error(newTypeError(&"unsupported slicing for object of type '{peeked.typeName()}'"))
                    return false
        else:
            self.error(newTypeError(&"unsupported slicing for object of type '{peeked.typeName()}'"))
            return false


proc sliceRange(self: var VM): bool =
    var sliceEnd = self.pop()
    var sliceStart = self.pop()
    var popped = self.pop()
    case popped.kind:
        of OBJECT:
            case popped.obj.kind:
                of ObjectType.String:
                    var str = popped.toStr()
                    if sliceEnd.isNil():
                        sliceEnd = Value(kind: INTEGER, intValue: len(str))
                    if sliceStart.isNil():
                        sliceStart = Value(kind: INTEGER, intValue: 0)
                    elif not sliceStart.isInt() or not sliceEnd.isInt():
                        self.error(newTypeError("string indeces must be integers"))
                        return false
                    elif sliceStart.toInt() < 0:
                        sliceStart.intValue = len(str) + sliceStart.toInt()
                    if sliceEnd.toInt() < 0:
                        sliceEnd.intValue = len(str) + sliceEnd.toInt()
                    if sliceStart.toInt() - 1 > len(str) - 1:
                        self.push(Value(kind: OBJECT, obj: addObject(addr self, newString(""))))
                        return true
                    if sliceEnd.toInt() - 1 > len(str) - 1:
                        sliceEnd = Value(kind: INTEGER, intValue: len(str))
                    if sliceStart.toInt() > sliceEnd.toInt():
                        self.push(Value(kind: OBJECT, obj: addObject(addr self, newString(""))))
                        return true
                    self.push(Value(kind: OBJECT, obj: addObject(addr self, newString(str[sliceStart.toInt()..<sliceEnd.toInt()]))))
                    return true
                else:
                    self.error(newTypeError(&"unsupported slicing for object of type '{popped.typeName()}'"))
                    return false
        else:
            self.error(newTypeError(&"unsupported slicing for object of type '{popped.typeName()}'"))
            return false


proc call(self: var VM, function: ptr Function, argCount: uint8): bool =
    var argCount = int argCount
    if argCount != function.arity:
        self.error(newTypeError(&"function '{stringify(function.name)}' takes {function.arity} argument(s), got {argCount}"))
        return false
    if self.frameCount == FRAMES_MAX:
        self.error(newRecursionError("max recursion depth exceeded"))
        return false
    var frame = CallFrame(function: function, ip: 0, slot: argCount + 1, stack: self.stack)
    self.frames.add(frame)
    self.frameCount += 1
    return true


proc callValue(self: var VM, callee: Value, argCount: uint8): bool =
    if callee.isObj():
        case callee.obj.kind:
            of ObjectType.Function:
                return self.call(cast[ptr Function](callee.obj), argCount)
            else:
                discard
    self.error(newTypeError(&"object of type '{callee.typeName}' is not callable"))
    return false


proc run(self: var VM, debug, repl: bool): InterpretResult =
    var frame = self.frames[self.frameCount - 1]
    template readByte: untyped =
        inc(frame.ip)
        frame.function.chunk.code[frame.ip - 1]
    template readBytes: untyped =
        var arr = [readByte(), readByte(), readByte()]
        var index: int
        copyMem(index.addr, unsafeAddr(arr), sizeof(arr))
        index
    template readShort: untyped =
        inc(frame.ip)
        inc(frame.ip)
        cast[uint16]((frame.function.chunk.code[frame.ip - 2] shl 8) or frame.function.chunk.code[frame.ip - 1])
    template readConstant: Value =
        frame.function.chunk.consts.values[int(readByte())]
    template readLongConstant: Value =
        var arr = [readByte(), readByte(), readByte()]
        var idx: int
        copyMem(idx.addr, unsafeAddr(arr), sizeof(arr))
        frame.function.chunk.consts.values[idx]
    template binOp(op, check) =
        var rightVal {.inject.} = self.pop()
        var leftVal {.inject.} = self.pop()
        if leftVal.isInf():
            leftVal = Inf.asFloat()
        elif leftVal.isNan():
            leftVal = Nan.asFloat()
        if rightVal.isNan():
            rightVal = Nan.asFloat()
        elif rightVal.isInf():
            rightVal = Inf.asFloat()
        if check(leftVal) and check(rightVal):
            if leftVal.isFloat() and rightVal.isInt():
                var res = `op`(leftVal.toFloat(), float rightVal.toInt())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                    var res = float res
                    if res == Inf:
                        self.push(Value(kind: ValueType.Inf))
                    elif res == -Inf:
                        self.push(Value(kind: ValueType.Minf))
                    else:
                       self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isInt() and rightVal.isFloat():
                var res = `op`(float leftVal.toInt(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                    var res = float res
                    if res == Inf:
                        self.push(Value(kind: ValueType.Inf))
                    elif res == -Inf:
                        self.push(Value(kind: ValueType.Minf))
                    else:
                       self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isFloat() and rightVal.isFloat():
                var res = `op`(leftVal.toFloat(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                    var res = float res
                    if res == Inf:
                        self.push(Value(kind: ValueType.Inf))
                    elif res == -Inf:
                        self.push(Value(kind: ValueType.Minf))
                    else:
                       self.push(Value(kind: DOUBLE, floatValue: float res))
            else:
                var tmp = `op`(leftVal.toInt(), rightVal.toInt())
                var res = float tmp
                if tmp is int:
                    self.push(Value(kind: ValueType.Integer, intValue: int tmp))
                elif res == Inf:
                    self.push(Value(kind: ValueType.Inf))
                elif res == -Inf:
                    self.push(Value(kind: ValueType.Minf))
                elif tmp is bool:
                    self.push(Value(kind: ValueType.Bool, boolValue: bool tmp))
                else:
                    self.push(Value(kind: ValueType.Double, floatValue: float tmp))
        else:
            self.error(newTypeError(&"unsupported binary operator for objects of type '{leftVal.typeName()}' and '{rightVal.typeName()}'"))
            return RUNTIME_ERROR
    template binBitWise(op): untyped =
        var rightVal {.inject.} = self.pop()
        var leftVal {.inject.} = self.pop()
        if isInt(leftVal) and isInt(rightVal):
            self.push(Value(kind: INTEGER, intValue: `op`(leftVal.toInt(), rightVal.toInt())))
        else:
            self.error(newTypeError(&"unsupported binary operator for objects of type '{leftVal.typeName()}' and '{rightVal.typeName()}'"))
            return RUNTIME_ERROR
    template unBitWise(op): untyped =
            var leftVal {.inject.} = self.pop()
            if isInt(leftVal):
                self.push(Value(kind: INTEGER, intValue: `op`(leftVal.toInt())))
            else:
                self.error(newTypeError(&"unsupported unary operator for object of type '{leftVal.typeName()}'"))
                return RUNTIME_ERROR
    var instruction: uint8
    var opcode: OpCode
    while true:
        {.computedgoto.}
        instruction = readByte()
        opcode = OpCode(instruction)
        if debug:   # Consider moving this elsewhere
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
        case opcode:
            of OpCode.Constant:
                var constant: Value = readConstant()
                self.push(constant)
            of OpCode.ConstantLong:
                var constant: Value = readLongConstant()
                self.push(constant)
            of OpCode.Negate:
                var cur = self.pop()
                case cur.kind:
                    of ValueType.Double:
                        cur.floatValue = -cur.toFloat()
                        self.push(cur)
                    of ValueType.Integer:
                        cur.intValue = -cur.toInt()
                        self.push(cur)
                    of ValueType.Inf:
                        self.push(Value(kind: ValueType.Minf))
                    of ValueType.Minf:
                        self.push(Value(kind: ValueType.Inf))
                    else:
                        self.error(newTypeError(&"unsupported unary operator for object of type '{cur.typeName()}'"))
                        return RUNTIME_ERROR
            of OpCode.Add:
                if self.peek(0).isObj() and self.peek(1).isObj():
                    if self.peek(0).isStr() and self.peek(1).isStr():
                        var r = self.peek(0).toStr()
                        var l = self.peek(1).toStr()
                        let res = Value(kind: OBJECT, obj: addObject(addr self, newString(l & r)))
                        discard self.pop()    # Garbage collector-related paranoia here
                        discard self.pop()
                        self.push(res)
                    else:
                        self.error(newTypeError(&"unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}'"))
                        return RUNTIME_ERROR
                else:
                    binOp(`+`, isNum)
            of OpCode.Shl:
                binBitWise(`shl`)
            of OpCode.Shr:
                binBitWise(`shr`)
            of OpCode.Xor:
                binBitWise(`xor`)
            of OpCode.Bor:
                binBitWise(bitor)
            of OpCode.Bnot:
                unBitWise(bitnot)
            of OpCode.Band:
                binBitWise(bitand)
            of OpCode.Subtract:
                binOp(`-`, isNum)
            of OpCode.Divide:
                binOp(`/`, isNum)
            of OpCode.Multiply:
                if self.peek(0).isInt() and self.peek(1).isObj():
                    if self.peek(1).isStr():
                        var r = self.pop().toInt()   # We don't peek here because integers are not garbage collected (not by us at least)
                        var l = self.peek(0).toStr()
                        let res = Value(kind: OBJECT, obj: addObject(addr self, newString(l.repeat(r))))
                        discard self.pop()
                        self.push(res)
                    else:
                        self.error(newTypeError(&"unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}'"))
                        return RUNTIME_ERROR
                elif self.peek(0).isObj() and self.peek(1).isInt():
                    if self.peek(0).isStr():
                        var r = self.peek(0).toStr()
                        var l = self.peek(1).toInt()
                        let res = Value(kind: OBJECT, obj: addObject(addr self, newString(r.repeat(l))))
                        discard self.pop()
                        self.push(res)
                    else:
                        self.error(newTypeError(&"unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}"))
                        return RUNTIME_ERROR
                else:
                    binOp(`*`, isNum)
            of OpCode.Mod:
                binOp(floorMod, isNum)
            of OpCode.Pow:
                binOp(`**`, isNum)
            of OpCode.True:
                self.push(Value(kind: ValueType.Bool, boolValue: true)) # TODO asBool() ?
            of OpCode.False:
                self.push(Value(kind: ValueType.Bool, boolValue: false))
            of OpCode.Nil:
                self.push(Value(kind: ValueType.Nil))
            of OpCode.Nan:
                self.push(Value(kind: ValueType.Nan))
            of OpCode.Inf:
                self.push(Value(kind: ValueType.Inf))
            of OpCode.Not:
                self.push(Value(kind: BOOL, boolValue: isFalsey(self.pop())))
            of OpCode.Equal:
                var a = self.pop()
                var b = self.pop()
                if a.isFloat() and b.isInt():
                    b = Value(kind: DOUBLE, floatValue: float b.toInt())
                elif b.isFloat() and a.isInt():
                    a = Value(kind: DOUBLE, floatValue: float a.toInt())
                self.push(Value(kind: BOOL, boolValue: valuesEqual(a, b)))
            of OpCode.Less:
                binOp(`<`, isNum)
            of OpCode.Greater:
                binOp(`>`, isNum)
            of OpCode.Slice:
                if not self.slice():
                    return RUNTIME_ERROR
            of OpCode.SliceRange:
                if not self.sliceRange():
                    return RUNTIME_ERROR
            of OpCode.DefineGlobal:
                if frame.function.chunk.consts.values.len > 255:
                    var constant = readLongConstant().toStr()
                    self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().toStr()
                    self.globals[constant] = self.peek(0)
                discard self.pop()   # This will help when we have a custom GC
            of OpCode.GetGlobal:
                if frame.function.chunk.consts.values.len > 255:
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
                if frame.function.chunk.consts.values.len > 255:
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
                # This OpCode, as well as OP_DELETE_LOCAL, is currently unused due to issues with the GC
                if frame.function.chunk.consts.values.len > 255:
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
                    # TODO unimplemented
                else:
                    var slot = readByte()
                    # TODO unimplemented
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
                    if not self.lastPop.isNil():
                        echo stringify(self.lastPop)
                        self.lastPop = Value(kind: ValueType.Nil) # TODO: asNil()?
                self.frameCount -= 1
                discard self.frames.pop()
                if self.frameCount == 0:
                    discard self.pop()
                    return OK
                self.push(retResult)
                self.stackTop = len(frame.slots) - 1 # TODO
                frame = self.frames[self.frameCount - 1]


proc freeObject(obj: ptr Obj, debug: bool) =
    case obj.kind:
        of ObjectType.String:
            var str = cast[ptr String](obj)
            if debug:
                echo &"Freeing string object with value '{stringify(str)}' of length {str.len}"
            discard freeArray(char, str.str, str.len)
            discard free(ObjectType.String, obj)
        of ObjectType.Function:
            var fun = cast[ptr Function](obj)
            if debug:
                echo &"Freeing function object with value '{stringify(fun)}'"
            fun.chunk.freeChunk()
            discard free(ObjectType.Function, fun)
        else:
            discard


proc freeObjects(self: var VM, debug: bool) =
    var objCount = len(self.objects)
    for obj in reversed(self.objects):
        freeObject(obj, debug)
        discard self.objects.pop()
    if debug:
        echo &"Freed {objCount} objects"


proc freeVM*(self: var VM, debug: bool) =
    if debug:
        echo "\nFreeing all allocated memory before exiting"
    unsetControlCHook()
    try:
        self.freeObjects(debug)
    except NilAccessError:
        echo "MemoryError: could not free memory, exiting"
        quit(71)


proc initVM*(): VM =
    setControlCHook(handleInterrupt)
    result = VM(lastPop: Value(kind: ValueType.Nil), objects: @[], globals: initTable[string, Value](), source: "", file: "")
    # TODO asNil() ?


proc interpret*(self: var VM, source: string, debug: bool = false, repl: bool = false, file: string): InterpretResult =
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
    self.push(Value(kind: OBJECT, obj: compiled))
    discard self.callValue(Value(kind: OBJECT, obj: compiled), 0)
    if debug:
        echo "==== Real-time VM debugging ====\n"
    try:
        result = self.run(debug, repl)
    except KeyboardInterrupt:
        self.error(newInterruptedError(""))
        return RUNTIME_ERROR
    if debug:
        echo "==== Real-time debugging ends ====\n"
