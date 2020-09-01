# Common functionality and objects shared across the entire JAPL ecosystem.
# This module exists to avoid recursive dependencies


import tables
import strformat
import meta/valueobject
import meta/tokenobject
import meta/looptype
import types/objecttype
import types/functiontype
import types/stringtype


type
    CallFrame* = object
        function*: ptr Function
        ip*: int
        slots*: seq[Value]


    VM* = object
        lastPop*: Value
        frameCount*: int
        source*: string
        frames*: seq[CallFrame]
        stack*: seq[Value]
        stackTop*: int
        objects*: ptr Obj
        globals*: Table[string, Value]
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


func stringify*(value: Value): string =
    case value.kind:
        of INTEGER:
            result = $value.toInt()
        of DOUBLE:
            result = $value.toFloat()
        of BOOL:
            result = $value.toBool()
        of NIL:
            result = "nil"
        of OBJECT:
            case value.obj.kind:
                of ObjectTypes.STRING:
                    result = cast[ptr String](value.obj)[].stringify
                of ObjectTypes.FUNCTION:
                    result = cast[ptr Function](value.obj)[].stringify
                else:
                    result = value.obj[].stringify()
        of ValueTypes.NAN:
            result = "nan"
        of ValueTypes.INF:
            result = "inf"
        of MINF:
            result = "-inf"


proc stringify*(frame: CallFrame): string =
    return &"CallFrame(slots={frame.slots}, ip={frame.ip}, function={stringify(frame.function[])})"


const FRAMES_MAX* = 400
const JAPL_VERSION* = "0.2.0"
const JAPL_RELEASE* = "alpha"
