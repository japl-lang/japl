# Common functionality and objects shared across the entire JAPL ecosystem.
# This module exists to avoid recursive dependencies


import tables
import meta/valueobject
import meta/tokenobject
import meta/looptype
import types/objecttype
import meta/chunk
import types/functiontype


type
    CallFrame* = object
        function*: ptr Function
        ip*: int
        slots*: ptr seq[Value]


    VM* = object
        source*: string
        frames*: seq[CallFrame]
        stack*: seq[Value]
        stackTop*: int
        objects*: ptr Obj
        globals*: Table[string, Value]
        lastPop*: Value
        file*: string

    Local* = ref object
       name*: Token
       depth*: int

    Compiler* = object
        enclosing*: ptr Compiler
        function*: ptr Function
        context*: FunctionType
        locals*: seq[Local]
        localCount*: int
        scopeDepth*: int
        parser*: Parser
        loop*: Loop
        vm*: VM
        file*: string

    Parser* = ref object
        current*: int
        tokens*: seq[Token]
        hadError*: bool
        panicMode*: bool
        file*: string


proc initParser*(tokens: seq[Token], file: string): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false, file: file)


const FRAMES_MAX* = 256
const STACK_MAX* = FRAMES_MAX * int uint8.high
