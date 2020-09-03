# Common functionality and objects shared across the entire JAPL ecosystem.
# This module exists to avoid recursive dependencies


import tables
import strformat
import strutils
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
        frames*: ref seq[CallFrame]
        stack*: ref seq[Value]
        stackTop*: int
        objects*: seq[ptr Obj]
        globals*: Table[string, Value]
        file*: string

    Local* = ref object
       name*: Token
       depth*: int

    Compiler* = object
        enclosing*: ref Compiler
        function*: ptr Function
        context*: FunctionType
        locals*: seq[Local]
        localCount*: int
        scopeDepth*: int
        parser*: Parser
        loop*: Loop
        vm*: ptr VM
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
                    result = cast[ptr String](value.obj).stringify
                of ObjectTypes.FUNCTION:
                    result = cast[ptr Function](value.obj).stringify
                else:
                    result = value.obj.stringify()
        of ValueTypes.NAN:
            result = "nan"
        of ValueTypes.INF:
            result = "inf"
        of MINF:
            result = "-inf"


proc stringify*(frame: CallFrame): string =
    return &"CallFrame(slots={frame.slots}, ip={frame.ip}, function={stringify(frame.function)})"


proc hashFloat(f: float): uint32 =
    result = 2166136261u32
    result = result xor uint32 f
    result *= 16777619
    return result


proc hash*(value: Value): uint32 =
    case value.kind:
        of INTEGER:
            result = uint32 value.toInt()
        of BOOL:
            if value.boolValue:
                result = uint32 1
            else:
                result = uint32 0
        of DOUBLE:
            result = hashFloat(value.toFloat())
        of OBJECT:
            case value.obj.kind:
                of ObjectTypes.STRING:
                    result = hash(cast[ptr String](value.obj))
                else:
                    result = hash(value.obj)
        else:   # More coming soon
            result = uint32 0


func isFalsey*(value: Value): bool =
    case value.kind:
        of BOOL:
            result = not value.toBool()
        of OBJECT:
            case value.obj.kind:
                of ObjectTypes.STRING:
                    result = cast[ptr String](value.obj).isFalsey()
                of ObjectTypes.FUNCTION:
                    result = cast[ptr Function](value.obj).isFalsey()
                else:
                    result = isFalsey(value.obj)
        of INTEGER:
            result = value.toInt() == 0
        of DOUBLE:
            result = value.toFloat() > 0.0
        of NIL:
            result = true
        of ValueTypes.INF, MINF:
            result = false
        of ValueTypes.NAN:
            result = true


func typeName*(value: Value): string =
    case value.kind:
        of BOOL, NIL, DOUBLE, INTEGER, ValueTypes.NAN, ValueTypes.INF:
            result = ($value.kind).toLowerAscii()
        of MINF:
           result = "inf"
        of OBJECT:
            case value.obj.kind:
                of ObjectTypes.STRING:
                    result = cast[ptr String](value.obj).typeName()
                of ObjectTypes.FUNCTION:
                    result = cast[ptr Function](value.obj).typeName()
                else:
                    result = value.obj.typeName()


proc valuesEqual*(a: Value, b: Value): bool =
    if a.kind != b.kind:
        result = false
    else:
        case a.kind:
            of BOOL:
                result = a.toBool() == b.toBool()
            of NIL:
                result = true
            of INTEGER:
                result = a.toInt() == b.toInt()
            of DOUBLE:
                result = a.toFloat() == b.toFloat()
            of OBJECT:
                case a.obj.kind:
                    of ObjectTypes.STRING:
                        var a = cast[ptr String](a.obj)
                        var b = cast[ptr String](b.obj)
                        result = valuesEqual(a, b)
                    of ObjectTypes.FUNCTION:
                        var a = cast[ptr Function](a.obj)
                        var b = cast[ptr Function](b.obj)
                        result = valuesEqual(a, b)
                    else:
                        result = valuesEqual(a.obj, b.obj)
            of ValueTypes.INF:
                result = b.kind == ValueTypes.INF
            of MINF:
                result = b.kind == MINF
            of ValueTypes.NAN:
                result = false



proc `$`*(frame: CallFrame): string =
    result = stringify(frame)


const FRAMES_MAX* = 400
const JAPL_VERSION* = "0.2.0"
const JAPL_RELEASE* = "alpha"
