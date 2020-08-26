# Common module for the entire JAPL ecosystem. This file
# servers the only purpose of avoiding recursive dependencies

import tables
import types/functiontype
import meta/valueobject
import meta/tokenobject
import meta/chunk
import meta/looptype
import types/objecttype

type
    VM* = object
        chunk*: Chunk
        ip*: int
        stack*: seq[Value]
        stackTop*: int
        objects*: ptr Obj
        globals*: Table[string, Value]
        lastPop*: Value

    Lexer* = ref object
        source*: string
        tokens*: seq[Token]
        line*: int
        start*: int
        current*: int
        errored*: bool

    Local* = ref object
       name*: Token
       depth*: int

    Compiler* = object
        function*: ptr Function
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


proc initCompiler*(vm: VM): Compiler =
    result = Compiler(parser: initParser(@[]), function: newFunction(), locals: @[], scopeDepth: 0, localCount: 0, loop: Loop(alive: false, loopEnd: -1), vm: vm)


