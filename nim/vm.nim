import meta/chunk
import meta/valueobject
import util/debug
import compiler
import strutils
import strformat
import lenientops


type InterpretResult = enum
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR


type VM = ref object
    chunk: Chunk
    ip: int
    stack*: seq[Value]
    stackTop*: int


proc pop(self: VM): Value =
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
    template BinOp(op) =
        var left = self.pop()
        var right = self.pop()
        if left.kind == FLOAT and right.kind == INT:
            var res = `op`(left.floatValue, right.intValue)
            self.push(Value(kind: FLOAT, floatValue: res))
        elif left.kind == INT and right.kind == FLOAT:
            var res = `op`(left.intValue, right.floatValue)
            self.push(Value(kind: FLOAT, floatValue: res))
        elif left.kind == INT and right.kind == INT:
            var res = cast[int](`op`(left.intValue, right.intValue))
            self.push(Value(kind: INT, intValue: res))
        else:
            var res = `op`(left.floatValue, right.floatValue)
            self.push(Value(kind: FLOAT, floatValue: res))
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
                    of FLOAT:
                        cur.floatValue = -cur.floatValue
                        self.push(cur)
                    of INT:
                        cur.intValue = -cur.intValue
                        self.push(cur)
                    else:
                        echo &"Unsupported unary operator '-' for object of type '{toLowerAscii($cur.kind)}'"
                        return RUNTIME_ERROR
            of OP_ADD:
                BinOp(`+`)
            of OP_SUBTRACT:
                BinOp(`-`)
            of OP_DIVIDE:
                BinOp(`/`)
            of OP_MULTIPLY:
                BinOp(`*`)
            of OP_RETURN:
                echo stringifyValue(self.pop())
                return OK


proc interpret*(self: var VM, source: string, debug: bool = false): InterpretResult =
    var chunk = initChunk()
    var compiler = initCompiler()
    if not compiler.compile(source, chunk):
        return COMPILE_ERROR
    self.chunk = chunk
    self.ip = 0
    result = vm.run(debug)
    chunk.freeChunk()


proc resetStack*(self: VM) =
    self.stackTop = 0


proc initVM*(): VM =
    result = VM(chunk: initChunk(), ip: 0, stack: @[], stackTop: 0)


proc freeVM*(self: VM) =
    return
