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
    callFrame* = object
        function*: ptr Function
        ip*: int
        slots*: ptr Value


    VM* = object
        chunk*: Chunk
        frames*: seq[callFrame]
        ip*: int
        stack*: seq[Value]
        stackTop*: int
        objects*: ptr Obj
        globals*: Table[string, Value]
        lastPop*: Value

    Local* = ref object
       name*: Token
       depth*: int

    Compiler* = object
        function*: ptr Function
        context*: FunctionType
        locals*: seq[Local]
        localCount*: int
        scopeDepth*: int
        parser*: Parser
        loop*: Loop
        vm*: VM

    Parser* = ref object
        current*: int
        tokens*: seq[Token]
        hadError*: bool
        panicMode*: bool


proc initParser*(tokens: seq[Token]): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false)
