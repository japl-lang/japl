import meta/chunk
import meta/valueobject
import meta/exceptions
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

proc error*(self: VM, message: string, kind: JAPLException) =
    echo &"{stringifyObject(kind.name)}: {message}"
    # Add code to raise an exception here


proc numOperand(operand: Value): bool =
    result = operand.kind in [DOUBLE, INTEGER]


proc pop*(self: VM): Value =
    result = self.stack.pop()
    self.stackTop = self.stackTop - 1


proc push*(self: VM, value: Value) =
    self.stack.add(value)
    self.stackTop = self.stackTop + 1


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
        var leftVal {.inject.} = self.pop()
        var rightVal {.inject.} = self.pop()
        if check(leftVal) and check(rightVal):
            if leftVal.kind == INTEGER and rightVal.kind == INTEGER:
                var left: int = leftVal.intValue
                var right: int = rightVal.intValue
                var res = `op`(right, left)
                if res is int:
                    self.push(Value(kind: INTEGER, intValue: int res))
                else:
                    self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.kind == DOUBLE and rightVal.kind == INTEGER:
                var left = leftVal.floatValue
                var right = float rightVal.intValue
                self.push(Value(kind: DOUBLE, floatValue: `op`(right, left)))
            elif leftVal.kind == INTEGER and rightVal.kind == DOUBLE:
                var left = float leftVal.intValue
                var right = rightVal.floatValue
                self.push(Value(kind: DOUBLE, floatValue: `op`(right, left)))
            else:
                var left = leftVal.floatValue
                var right = rightVal.floatValue
                self.push(Value(kind: DOUBLE, floatValue: `op`(right, left)))
        else:
            self.error(&"Unsupported binary operand for objects of type '{toLowerAscii($(leftVal.kind))}' and '{toLowerAscii($(rightVal.kind))}'", newTypeError())
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
                stdout.write(stringifyValue(v))
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
                BinOp(`+`, numOperand)
            of OP_SUBTRACT:
                BinOp(`-`, numOperand)
            of OP_DIVIDE:
                BinOp(`/`, numOperand)
            of OP_MULTIPLY:
                BinOp(`*`, numOperand)
            of OP_MOD:
                BinOp(floorMod, numOperand)
            of OP_POW:
                BinOp(`**`, numOperand)
            of OP_TRUE:
                self.push(Value(kind: BOOL, boolValue: true))
            of OP_FALSE:
                self.push(Value(kind: BOOL, boolValue: false))
            of OP_NIL:
                self.push(Value(kind: NIL))
            of OP_RETURN:
                echo stringifyValue(self.pop())
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
