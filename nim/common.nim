# Common functionality and objects shared across the entire JAPL ecosystem.
# This module exists mainly to avoid recursive dependencies


import tables
import strutils
import meta/valueobject
import meta/tokenobject
import types/objecttype
import types/functiontype
import types/stringtype


const FRAMES_MAX* = 4
const JAPL_VERSION* = "0.2.0"
const JAPL_RELEASE* = "alpha"
const DEBUG_TRACE_VM* = false
const DEBUG_TRACE_GC* = true
const DEBUG_TRACE_ALLOCATION* = true
const DEBUG_TRACE_COMPILER* = true


type
    CallFrame* = ref object
        function*: ptr Function
        ip*: int
        slot*: int
        stack*: seq[Value]

    VM* = ref object
        lastPop*: Value
        frameCount*: int
        source*: string
        frames*: seq[CallFrame]
        stack*: seq[Value]
        stackTop*: int
        objects*: seq[ptr Obj]
        globals*: Table[string, Value]
        file*: string

    Local* = ref object
       name*: Token
       depth*: int


    Parser* = ref object
        current*: int
        tokens*: seq[Token]
        hadError*: bool
        panicMode*: bool
        file*: string


proc getAbsIndex(self: CallFrame, idx: int): int =
    return idx + len(self.stack[self.slot..len(self.stack) - 1]) - 1


proc getView*(self: CallFrame): seq[Value] =
    result = self.stack[self.slot..len(self.stack) - 1]


proc len*(self: CallFrame): int =
    result = len(self.getView())


proc `[]`*(self: CallFrame, idx: int): Value =
    result = self.getView()[idx]


proc `[]=`*(self: CallFrame, idx: int, val: Value) =
    if idx < self.slot:
        raise newException(IndexError, "CallFrame index out of range")
    self.stack[self.getAbsIndex(idx)] = val


proc delete*(self: CallFrame, idx: int) = 
    if idx < self.slot:
        raise newException(IndexError, "CallFrame index out of range")
    self.stack.delete(idx)


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
                of ObjectType.String:
                    result = cast[ptr String](value.obj).stringify
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).stringify
                else:
                    result = value.obj.stringify()
        of ValueType.Nan:
            result = "nan"
        of ValueType.Inf:
            result = "inf"
        of MINF:
            result = "-inf"


proc initParser*(tokens: seq[Token], file: string): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false, file: file)


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
                of ObjectType.String:
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
                of ObjectType.String:
                    result = cast[ptr String](value.obj).isFalsey()
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).isFalsey()
                else:
                    result = isFalsey(value.obj)
        of INTEGER:
            result = value.toInt() == 0
        of DOUBLE:
            result = value.toFloat() > 0.0
        of NIL:
            result = true
        of ValueType.Inf, ValueType.Minf:
            result = false
        of ValueType.Nan:
            result = true


func typeName*(value: Value): string =
    case value.kind:
        of ValueType.Bool, ValueType.Nil, ValueType.Double,
          ValueType.Integer, ValueType.Nan, ValueType.Inf:
            result = ($value.kind).toLowerAscii()
        of MINF:
           result = "inf"
        of OBJECT:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).typeName()
                of ObjectType.Function:
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
                    of ObjectType.String:
                        var a = cast[ptr String](a.obj)
                        var b = cast[ptr String](b.obj)
                        result = valuesEqual(a, b)
                    of ObjectType.Function:
                        var a = cast[ptr Function](a.obj)
                        var b = cast[ptr Function](b.obj)
                        result = valuesEqual(a, b)
                    else:
                        result = valuesEqual(a.obj, b.obj)
            of ValueType.Inf:
                result = b.kind == ValueType.Inf
            of MINF:
                result = b.kind == ValueType.Minf
            of ValueType.Nan:
                result = false

