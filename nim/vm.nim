import meta/chunk
import meta/valueobject
import types/exceptions
import types/objecttype
import util/debug
import compiler
import strutils
import strformat
import math
import lenientops
import lists
import tables


proc `**`(a, b: int): int = pow(a.float, b.float).int


proc `**`(a, b: float): float = pow(a, b)


type InterpretResult = enum
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR


type VM = ref object
    chunk: Chunk
    ip: int
    stack*: seq[Value]
    stackTop*: int
    objects*: SinglyLinkedList[Obj]  # Unused for now
    globals*: Table[string, Value]


proc error*(self: VM, error: JAPLException) =
    echo stringify(error)
    # Add code to raise an exception here


proc pop*(self: VM): Value =
    result = self.stack.pop()
    self.stackTop = self.stackTop - 1


proc push*(self: VM, value: Value) =
    self.stack.add(value)
    self.stackTop = self.stackTop + 1


proc peek*(self: VM, distance: int): Value =
    return self.stack[len(self.stack) - distance - 1]


proc slice(self: VM): bool =
    var idx = self.pop()
    var peeked = self.pop()
    case peeked.kind:
        of OBJECT:
            case peeked.obj.kind:
                of STRING:
                    var str = peeked.obj.str
                    if idx.kind != INTEGER:
                        self.error(newTypeError("string indeces must be integers"))
                        return false
                    elif idx.intValue - 1 > len(str) - 1:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    elif idx.intValue < 0:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: &"{str[idx.intValue]}")))
                    return true

                else:
                    self.error(newTypeError(&"Unsupported slicing for object of type '{toLowerAscii($(peeked.kind))}'"))
                    return false
        else:
            self.error(newTypeError(&"Unsupported slicing for object of type '{toLowerAscii($(peeked.kind))}'"))
            return false


proc sliceRange(self: VM): bool =
    var sliceEnd = self.pop()
    var sliceStart = self.pop()
    var popped = self.pop()
    case popped.kind:
        of OBJECT:
            case popped.obj.kind:
                of STRING:
                    var str = popped.obj.str
                    if sliceEnd.kind == NIL:
                        sliceEnd = Value(kind: INTEGER, intValue: len(str) - 1)
                    if sliceStart.kind == NIL:
                        sliceStart = Value(kind: INTEGER, intValue: 0)
                    if sliceStart.kind != INTEGER or sliceEnd.kind != INTEGER:
                        self.error(newTypeError("string indeces must be integers"))
                        return false
                    elif sliceStart.intValue - 1 > len(str) - 1 or sliceEnd.intValue - 1 > len(str) - 1:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    elif sliceStart.intValue < 0 or sliceEnd.intValue < 0:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: str[sliceStart.intValue..sliceEnd.intValue])))
                    return true

                else:
                    self.error(newTypeError(&"Unsupported slicing for object of type '{toLowerAscii($(popped.kind))}'"))
                    return false
        else:
            self.error(newTypeError(&"Unsupported slicing for object of type '{toLowerAscii($(popped.kind))}'"))
            return false


proc run(self: VM, debug, repl: bool): InterpretResult =
    template readByte: untyped =
        inc(self.ip)
        self.chunk.code[self.ip - 1]
    template readBytes: untyped =
        var arr = [readByte(), readByte(), readByte()]
        var index: int
        copyMem(index.addr, unsafeAddr(arr), sizeof(arr))
        index
    template readConstant: Value =
        self.chunk.consts.values[int(readByte())]
    template readLongConstant: Value =
        var arr = [readByte(), readByte(), readByte()]
        var idx: int
        copyMem(idx.addr, unsafeAddr(arr), sizeof(arr))
        self.chunk.consts.values[idx]
    template BinOp(op, check) =
        var rightVal {.inject.} = self.pop()
        var leftVal {.inject.} = self.pop()
        if check(leftVal) and check(rightVal):
            if leftVal.isFloat() and rightVal.isInt():
                var res = `op`(leftVal.toFloat(), float rightVal.toInt())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                   self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isInt() and rightVal.isFloat():
                var res = `op`(float leftVal.toInt(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                   self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isFloat() and rightVal.isFloat():
                var res = `op`(leftVal.toFloat(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
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
            self.error(newTypeError(&"Unsupported binary operand for objects of type '{toLowerAscii($(leftVal.kind))}' and '{toLowerAscii($(rightVal.kind))}'"))
            return RUNTIME_ERROR
    var instruction: uint8
    var opcode: OpCode
    while true:
        {.computedgoto.}
        instruction = readByte()
        opcode = OpCode(instruction)
        if debug:
            stdout.write("Current stack status: [")
            for v in self.stack:
                stdout.write(stringify(v))
                stdout.write(", ")
            stdout.write("]\n")
            stdout.write("Global scope status: {")
            for k, v in self.globals.pairs():
                stdout.write(k)
                stdout.write(": ")
                stdout.write(stringify(v))
            echo "}\n"
            discard disassembleInstruction(self.chunk, self.ip - 1)
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
                        cur.floatValue = -cur.floatValue
                        self.push(cur)
                    of INTEGER:
                        cur.intValue = -cur.intValue
                        self.push(cur)
                    else:
                        echo &"Unsupported unary operator '-' for object of type '{toLowerAscii($cur.kind)}'"
                        return RUNTIME_ERROR
            of OP_ADD:
                if self.peek(0).kind == OBJECT and self.peek(1).kind == OBJECT:
                    if self.peek(0).obj.kind == STRING and self.peek(1).obj.kind == STRING:
                        var r = self.peek(0).obj.str
                        var l = self.peek(1).obj.str
                        self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: l & r)))
                    else:
                        self.error(newTypeError(&"Unsupported binary operand for objects of type '{toLowerAscii($(self.peek(0).kind))}' and '{toLowerAscii($(self.peek(1).kind))}'"))
                        return RUNTIME_ERROR
                else:
                    BinOp(`+`, isNum)
            of OP_SUBTRACT:
                BinOp(`-`, isNum)
            of OP_DIVIDE:
                BinOp(`/`, isNum)
            of OP_MULTIPLY:
                if self.peek(0).kind == INTEGER and self.peek(1).kind == OBJECT:
                    if self.peek(1).obj.kind == STRING:
                        var r = self.peek(0).intValue
                        var l = self.peek(1).obj.str
                        self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: l.repeat(r))))
                    else:
                        self.error(newTypeError(&"Unsupported binary operand for objects of type '{toLowerAscii($(self.peek(0).kind))}' and '{toLowerAscii($(self.peek(1).kind))}'"))
                        return RUNTIME_ERROR
                elif self.peek(0).kind == OBJECT and self.peek(1).kind == INTEGER:
                    if self.peek(0).obj.kind == STRING:
                        var r = self.peek(0).obj.str
                        var l = self.peek(1).intValue
                        self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: r.repeat(l))))
                    else:
                        self.error(newTypeError(&"Unsupported binary operand for objects of type '{toLowerAscii($(self.peek(0).kind))}' and '{toLowerAscii($(self.peek(1).kind))}'"))
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
            of OP_NOT:
                self.push(Value(kind: BOOL, boolValue: isFalsey(self.pop())))
            of OP_EQUAL:
                var a = self.pop()
                var b = self.pop()
                if a.kind == DOUBLE and b.kind == INTEGER:
                    b = Value(kind: DOUBLE, floatValue: float b.intValue)
                elif b.kind == DOUBLE and a.kind == INTEGER:
                    a = Value(kind: DOUBLE, floatValue: float a.intValue)
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
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().obj.str
                    self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().obj.str
                    self.globals[constant] = self.peek(0)
                discard self.pop()   # This will help when we have a custom GC
            of OP_GET_GLOBAL:
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().obj.str
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.push(self.globals[constant])
                else:
                    var constant = readConstant().obj.str
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.push(self.globals[constant])
            of OP_SET_GLOBAL:
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().obj.str
                    if constant notin self.globals:
                        self.error(newReferenceError(&"assignment to undeclared name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().obj.str
                    if constant notin self.globals:
                        self.error(newReferenceError(&"assignment to undeclared name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals[constant] = self.peek(0)
            of OP_DELETE_GLOBAL:
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().obj.str
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals.del(constant)
                else:
                    var constant = readConstant().obj.str
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals.del(constant)
            of OP_GET_LOCAL:
                if self.chunk.consts.values.len > 255:
                    var slot = readBytes()
                    self.push(self.stack[slot])
                else:
                    var slot = readByte()
                    self.push(self.stack[slot])
            of OP_SET_LOCAL:
                if self.chunk.consts.values.len > 255:
                    var slot = readBytes()
                    self.stack[slot] = self.peek(0)
                else:
                    var slot = readByte()
                    self.stack[slot] = self.peek(0)
            of OP_DELETE_LOCAL:
                if self.chunk.consts.values.len > 255:
                    var slot = readBytes()
                    self.stack.delete(slot)
                else:
                    var slot = readByte()
                    self.stack.delete(slot)
            of OP_POP:
                var popped = self.pop()
                if repl:
                    if popped.kind != NIL:
                        echo stringify(popped)
            of OP_RETURN:
                return OK


proc interpret*(self: var VM, source: string, debug: bool = false, repl: bool = false): InterpretResult =
    var chunk = initChunk()
    var compiler = initCompiler(chunk)
    if not compiler.compile(source, chunk):
        return COMPILE_ERROR
    self.chunk = chunk
    self.ip = 0
    if len(chunk.code) > 1:
        result = self.run(debug, repl)
    chunk.freeChunk()


proc resetStack*(self: VM) =
    self.stackTop = 0


proc initVM*(): VM =
    result = VM(chunk: initChunk(), ip: 0, stack: @[], stackTop: 0, objects: initSinglyLinkedList[Obj](), globals: initTable[string, Value]())


proc freeVM*(self: VM) =
    return
