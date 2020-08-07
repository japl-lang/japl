import meta/chunk


type InterpretResult = enum
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR

type VM = ref object
    chunk: Chunk
    ip: int


proc run(self: VM): InterpretResult =
    template readByte: untyped =
        inc(self.ip)
        self.chunk.code[self.ip - 1]

    var instruction: uint8
    var opcode: OpCode
    while true:
        {.computedgoto.}
        instruction = readByte()
        opcode = OpCode(instruction)
        case opcode:
            of OP_RETURN:
                return OK
            of OP_CONSTANT:
                return OK
            of OP_CONSTANT_LONG:
                return OK


proc interpret*(self: var VM, chunk: var Chunk): InterpretResult =
    self.chunk = chunk
    self.ip = 0
    result = self.run()


proc initVM*(): VM =
    result = VM(chunk: initChunk(), ip: 0)


proc freeVM*(self: VM) =
    return
