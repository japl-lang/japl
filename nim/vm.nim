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


proc error*(self: var VM, error: ptr JAPLException) =
    var previous = ""  # All this stuff seems overkill, but it makes the traceback look nicer
    var repCount = 0   # and if we are here we are far beyond a point where performance matters
    var mainReached = false
    var output = ""
    echo "Traceback (most recent call last):"
    for frame in reversed(self.frames):
        if mainReached:
            break
        var function = frame.function
        var line = function.chunk.lines[frame.ip]
        if function.name == nil:
            output = &"  File '{self.file}', line {line}, in '<module>':"
            mainReached = true
        else:
            output = &"  File '{self.file}', line {line}, in {stringify(function.name[])}():"
        if output != previous:
            if repCount > 0:
                echo &"   ...repeated {repCount} more times..."
            repCount = 0
            previous = output
            echo output
        else:
            repCount += 1
    echo error.stringify()


proc pop*(self: var VM): Value =
    result = self.stack.pop()
    self.stackTop -= 1


proc push*(self: var VM, value: Value) =
    self.stack.add(value)
    self.stackTop += 1


proc peek*(self: var VM, distance: int): Value =
    return self.stack[self.stackTop - distance - 1]


template markObject*(self, obj: untyped): untyped =
    obj.next = self.objects
    self.objects = obj
    obj


proc slice(self: var VM): bool =
    var idx = self.pop()
    var peeked = self.pop()
    case peeked.kind:
        of OBJECT:
            case peeked.obj.kind:
                of ObjectTypes.STRING:
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
                    self.push(Value(kind: OBJECT, obj: self.markObject(newString(&"{str[idx.toInt()]}"))))
                    return true

                else:
                    self.error(newTypeError(&"Unsupported slicing for object of type '{peeked.typeName()}'"))
                    return false
        else:
            self.error(newTypeError(&"Unsupported slicing for object of type '{peeked.typeName()}'"))
            return false


proc sliceRange(self: var VM): bool =
    var sliceEnd = self.pop()
    var sliceStart = self.pop()
    var popped = self.pop()
    case popped.kind:
        of OBJECT:
            case popped.obj.kind:
                of ObjectTypes.STRING:
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
                        if sliceStart.toInt() < 0:
                            self.error(newIndexError("string index out of bounds"))
                            return false
                    if sliceEnd.toInt() < 0:
                        sliceEnd.intValue = len(str) + sliceEnd.toInt()
                        if sliceEnd.toInt() < 0:
                            self.error(newIndexError("string index out of bounds"))
                            return false
                    if sliceStart.toInt() - 1 > len(str) - 1 or sliceEnd.toInt() - 1 > len(str) - 1:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    elif sliceStart.toInt() > sliceEnd.toInt():
                        self.error(newIndexError("the start index can't be bigger than the end index"))
                        return false
                    self.push(Value(kind: OBJECT, obj: self.markObject(newString(str[sliceStart.toInt()..<sliceEnd.toInt()]))))
                    return true

                else:
                    self.error(newTypeError(&"Unsupported slicing for object of type '{popped.typeName()}'"))
                    return false
        else:
            self.error(newTypeError(&"Unsupported slicing for object of type '{popped.typeName()}'"))
            return false


proc call(self: var VM, function: ptr Function, argCount: uint8): bool =
    if argCount != uint8 function.arity:
        self.error(newTypeError(&"Function '{stringify(function.name[])}' takes {function.arity} argument(s), got {argCount}"))
        return false
    if self.frameCount == FRAMES_MAX:
        self.error(newRecursionError("Max recursion depth exceeded"))
        return false
    var frame = CallFrame(function: function, ip: 0, slots: self.stack[argCount..self.stackTop - 1])
    self.frames.add(frame)
    self.frameCount += 1
    return true


proc callValue(self: var VM, callee: Value, argCount: uint8): bool =
    if callee.isObj():
        case callee.obj.kind:
            of ObjectTypes.FUNCTION:
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
    template BinOp(op, check) =
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
                        self.push(Value(kind: ValueTypes.INF))
                    elif res == -Inf:
                        self.push(Value(kind: MINF))
                    else:
                       self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isInt() and rightVal.isFloat():
                var res = `op`(float leftVal.toInt(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                    var res = float res
                    if res == Inf:
                        self.push(Value(kind: ValueTypes.INF))
                    elif res == -Inf:
                        self.push(Value(kind: MINF))
                    else:
                       self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isFloat() and rightVal.isFloat():
                var res = `op`(leftVal.toFloat(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                    var res = float res
                    if res == Inf:
                        self.push(Value(kind: ValueTypes.INF))
                    elif res == -Inf:
                        self.push(Value(kind: MINF))
                    else:
                       self.push(Value(kind: DOUBLE, floatValue: float res))
            else:
                var tmp = `op`(leftVal.toInt(), rightVal.toInt())
                if tmp is int:
                    self.push(Value(kind: INTEGER, intValue: int tmp))
                elif tmp is bool:
                    self.push(Value(kind: BOOL, boolValue: bool tmp))
                else:
                    self.push(Value(kind: DOUBLE, floatValue: float tmp))
        else:
            self.error(newTypeError(&"Unsupported binary operator for objects of type '{leftVal.typeName()}' and '{rightVal.typeName()}'"))
            return RUNTIME_ERROR
    template BitWise(op): untyped =
        var rightVal {.inject.} = self.pop()
        var leftVal {.inject.} = self.pop()
        if isInt(leftVal) and isInt(rightVal):
            self.push(Value(kind: INTEGER, intValue: `op`(leftVal.toInt(), rightVal.toInt())))
        else:
            self.error(newTypeError(&"Unsupported binary operator for objects of type '{leftVal.typeName()}' and '{rightVal.typeName()}'"))
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
            stdout.write(&"Current frame: {stringify(frame)}\n")
            stdout.write("Current frame type:")
            if frame.function.name == nil:
                stdout.write(" main\n")
            else:
                stdout.write(&" function, '{frame.function.name[].stringify()}'\n")
            stdout.write(&"Current frame count: {self.frameCount}\n")
            stdout.write("Current frame stack status: ")
            if frame.function.name == nil:
                stdout.write("see VM stack\n")
            else:
                stdout.write("[")
                for v in frame.slots:
                    stdout.write(stringify(v))
                    stdout.write(", ")
                stdout.write("]\n")
            discard disassembleInstruction(frame.function.chunk, frame.ip - 1)
        case opcode:
            of OP_CONSTANT:
                var constant: Value = readConstant()
                self.push(constant)
            of OP_CONSTANT_LONG:
                var constant: Value = readLongConstant()
                self.push(constant)
            of OP_NEGATE:
                var cur = self.pop()
                case cur.kind:
                    of DOUBLE:
                        cur.floatValue = -cur.toFloat()
                        self.push(cur)
                    of INTEGER:
                        cur.intValue = -cur.toInt()
                        self.push(cur)
                    of ValueTypes.INF:
                        self.push(Value(kind: MINF))
                    of ValueTypes.MINF:
                        self.push(Value(kind: ValueTypes.INF))
                    else:
                        self.error(newTypeError(&"Unsupported unary operator for object of type '{cur.typeName()}'"))
                        return RUNTIME_ERROR
            of OP_ADD:
                if self.peek(0).isObj() and self.peek(1).isObj():
                    if self.peek(0).isStr() and self.peek(1).isStr():
                        var r = self.pop().toStr()
                        var l = self.pop().toStr()
                        self.push(Value(kind: OBJECT, obj: self.markObject(newString(l & r))))
                    else:
                        self.error(newTypeError(&"Unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}'"))
                        return RUNTIME_ERROR
                else:
                    BinOp(`+`, isNum)
            of OP_SHL:
                BitWise(`shl`)
            of OP_SHR:
                BitWise(`shr`)
            of OP_XOR:
                BitWise(`xor`)
            of OP_SUBTRACT:
                BinOp(`-`, isNum)
            of OP_DIVIDE:
                BinOp(`/`, isNum)
            of OP_MULTIPLY:
                if self.peek(0).isInt() and self.peek(1).isObj():
                    if self.peek(1).isStr():
                        var r = self.pop().toInt()
                        var l = self.pop().toStr()
                        self.push(Value(kind: OBJECT, obj: self.markObject(newString(l.repeat(r)))))
                    else:
                        self.error(newTypeError(&"Unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}'"))
                        return RUNTIME_ERROR
                elif self.peek(0).isObj() and self.peek(1).isInt():
                    if self.peek(0).isStr():
                        var r = self.pop().toStr()
                        var l = self.pop().toInt()
                        self.push(Value(kind: OBJECT, obj: self.markObject(newString(r.repeat(l)))))
                    else:
                        self.error(newTypeError(&"Unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}"))
                        return RUNTIME_ERROR
                else:
                    BinOp(`*`, isNum)
            of OP_MOD:
                BinOp(floorMod, isNum)
            of OP_POW:
                BinOp(`**`, isNum)
            of OP_TRUE:
                self.push(Value(kind: BOOL, boolValue: true))
            of OP_FALSE:
                self.push(Value(kind: BOOL, boolValue: false))
            of OP_NIL:
                self.push(Value(kind: NIL))
            of OP_NAN:
                self.push(Value(kind: ValueTypes.NAN))
            of OP_INF:
                self.push(Value(kind: ValueTypes.INF))
            of OP_NOT:
                self.push(Value(kind: BOOL, boolValue: isFalsey(self.pop())))
            of OP_EQUAL:
                var a = self.pop()
                var b = self.pop()
                if a.isFloat() and b.isInt():
                    b = Value(kind: DOUBLE, floatValue: float b.toInt())
                elif b.isFloat() and a.isInt():
                    a = Value(kind: DOUBLE, floatValue: float a.toInt())
                self.push(Value(kind: BOOL, boolValue: valuesEqual(a, b)))
            of OP_LESS:
                BinOp(`<`, isNum)
            of OP_GREATER:
                BinOp(`>`, isNum)
            of OP_SLICE:
                if not self.slice():
                    return RUNTIME_ERROR
            of OP_SLICE_RANGE:
                if not self.sliceRange():
                    return RUNTIME_ERROR
            of OP_DEFINE_GLOBAL:
                if frame.function.chunk.consts.values.len > 255:
                    var constant = readLongConstant().toStr()
                    self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().toStr()
                    self.globals[constant] = self.peek(0)
                discard self.pop()   # This will help when we have a custom GC
            of OP_GET_GLOBAL:
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
            of OP_SET_GLOBAL:
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
            of OP_DELETE_GLOBAL:
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
            of OP_GET_LOCAL:
                if frame.slots.len > 255:
                    var slot = readBytes()
                    self.push(frame.slots[slot])
                else:
                    var slot = readByte()
                    self.push(frame.slots[slot])
            of OP_SET_LOCAL:
                if frame.slots.len > 255:
                    var slot = readBytes()
                    frame.slots[slot] = self.peek(0)
                else:
                    var slot = readByte()
                    frame.slots[slot] = self.peek(0)
            of OP_DELETE_LOCAL:
                if frame.slots.len > 255:
                    var slot = readBytes()
                    frame.slots.delete(slot)
                else:
                    var slot = readByte()
                    frame.slots.delete(slot)
            of OP_POP:
                self.lastPop = self.pop()
            of OP_JUMP_IF_FALSE:
                var offset = readShort()
                if isFalsey(self.peek(0)):
                    frame.ip += int offset
            of OP_JUMP:
                var offset = readShort()
                frame.ip += int offset
            of OP_LOOP:
                var offset = readShort()
                frame.ip -= int offset
            of OP_CALL:
                var argCount = readByte()
                if not self.callValue(self.peek(int argCount), argCount):
                    return RUNTIME_ERROR
                frame = self.frames[self.frameCount - 1]
            of OP_BREAK:
                discard
            of OP_RETURN:
                var retResult = self.pop()
                self.frameCount -= 1
                discard self.frames.pop()
                if repl:
                    if not self.lastPop.isNil():
                        echo stringify(self.lastPop)
                        self.lastPop = Value(kind: NIL)
                if self.frameCount == 0:
                    discard self.pop()
                    return OK
                self.push(retResult)
                self.stackTop = len(frame.slots)
                frame = self.frames[self.frameCount - 1]


proc freeObject(obj: ptr Obj, debug: bool) =
    case obj.kind:
        of ObjectTypes.STRING:
            var str = cast[ptr String](obj)
            if debug:
                echo &"Freeing string object with value '{stringify(str[])}' of length {str.len}"
            discard freeArray(char, str.str, str.len)
            discard free(ObjectTypes.STRING, obj)
        of ObjectTypes.FUNCTION:
            var fun = cast[ptr Function](obj)
            echo "Freeing function object with value '{stringify(fun[])}'"
            fun.chunk.freeChunk()
            discard free(ObjectTypes.FUNCTION, fun)
        else:
            discard


proc freeObjects(self: var VM, debug: bool) =
    var obj = self.objects
    var next: ptr Obj
    var i = 0
    while obj != nil:
        next = obj[].next
        freeObject(obj, debug)
        i += 1
        obj = next
    if debug:
        echo &"Freed {i} objects"


proc freeVM*(self: var VM, debug: bool) =
    if debug:
        echo "\nFreeing all allocated memory before exiting"
    unsetControlCHook()
    try:
        self.freeObjects(debug)
    except NilAccessError:
        echo "MemoryError: could not free memory, exiting"
        quit(71)


proc resetStack*(self: var VM) =
    self.stack = @[]
    self.frames = @[]
    self.frameCount = 0
    self.stackTop = 0


proc initVM*(): VM =
    setControlCHook(handleInterrupt)
    result = VM(lastPop: Value(kind: NIL), frameCount: 0, frames: @[], stack: @[], stackTop: 0, objects: nil, globals: initTable[string, Value](), source: "", file: "")


proc interpret*(self: var VM, source: string, debug: bool = false, repl: bool = false, file: string): InterpretResult =
    var compiler = initCompiler(self, SCRIPT, file=file)
    var compiled = compiler.compile(source)
    self.source = source
    self.file = file
    if compiled == nil:
        return COMPILE_ERROR
    self.push(Value(kind: OBJECT, obj: compiled))
    discard self.callValue(Value(kind: OBJECT, obj: compiled), 0)
    try:
        result = self.run(debug, repl)
    except KeyboardInterrupt:
        self.error(newInterruptedError(""))
        return RUNTIME_ERROR
    self.resetStack()
