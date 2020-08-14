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


proc error*(self: VM, kind: JAPLException) =
    echo &"{stringify(kind.errName)}: {stringify(kind.message)}"
    # Add code to raise an exception here


proc pop*(self: VM): Value =
    result = self.stack.pop()
    self.stackTop = self.stackTop - 1


proc push*(self: VM, value: Value) =
    self.stack.add(value)
    self.stackTop = self.stackTop + 1


proc peek*(self: VM, distance: int): Value =
    return self.stack[len(self.stack) - distance - 1]


proc run(self: VM, debug: bool): InterpretResult =
    template readByte: untyped =
        inc(self.ip)
        self.chunk.code[self.ip - 1]
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
                        self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: l[0..len(l) - 2] & r[1..<len(r)])))
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
                        self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: l[0] & l[1..len(l) - 2].repeat(r) & l[len(l) - 1])))
                    else:
                        self.error(newTypeError(&"Unsupported binary operand for objects of type '{toLowerAscii($(self.peek(0).kind))}' and '{toLowerAscii($(self.peek(1).kind))}'"))
                        return RUNTIME_ERROR
                elif self.peek(0).kind == OBJECT and self.peek(1).kind == INTEGER:
                    if self.peek(0).obj.kind == STRING:
                        var r = self.peek(0).obj.str
                        var l = self.peek(1).intValue
                        self.push(Value(kind: OBJECT, obj: Obj(kind: STRING, str: r[0] & r[1..len(r) - 2].repeat(l) & r[len(r) - 1])))
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
                self.push(Value(kind: BOOL, boolValue: valuesEqual(a, b)))
            of OP_LESS:
                BinOp(`<`, isNum)
            of OP_GREATER:
                BinOp(`>`, isNum)
            of OP_RETURN:
                echo stringify(self.pop())
                return OK


proc interpret*(self: var VM, source: string, debug: bool = false): InterpretResult =
    var chunk = initChunk()
    var compiler = initCompiler(chunk)
    if not compiler.compile(source, chunk):
        return COMPILE_ERROR
    self.chunk = chunk
    self.ip = 0
    if len(chunk.code) > 1:
        result = self.run(debug)
    chunk.freeChunk()


proc resetStack*(self: VM) =
    self.stackTop = 0


proc initVM*(): VM =
    result = VM(chunk: initChunk(), ip: 0, stack: @[], stackTop: 0)


proc freeVM*(self: VM) =
    return
