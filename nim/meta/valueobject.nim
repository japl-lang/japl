# This module represents the generic interface that JAPL uses internally
# to represent types. Small-sized entities such as numbers and booleans are
# treated differently with respect to bigger and more complex ones such as
# strings and functions. That is because those more comolex entities are
# allocated on the heap, while the simpler ones live on the stack

# import ../types/functiontype
import ../types/objecttype
import ../types/stringtype
import strformat
import strutils


type
    ValueTypes* = enum   # All possible value types (this is the VM's notion of 'type', not the end user's)
        INTEGER, DOUBLE, BOOL, NIL, OBJECT, NAN, INF, MINF
    Value* = object
        case kind*: ValueTypes
            of INTEGER:
                intValue*: int
            of DOUBLE:
                floatValue*: float
            of BOOL:
                boolValue*: bool
            of NIL, INF, NAN, MINF:
                discard
            of OBJECT:
                obj*: ptr Obj

    ValueArray* = ref object
        values*: seq[Value]


func initValueArray*(): ValueArray =
    result = ValueArray(values: @[])


func writeValueArray*(arr: var ValueArray, value: Value) =
    arr.values.add(value)


func isNil*(value: Value): bool =
    result = value.kind == NIL


func isBool*(value: Value): bool =
    result = value.kind == BOOL


func isInt*(value: Value): bool =
    result = value.kind == INTEGER


func isFloat*(value: Value): bool =
    result = value.kind == DOUBLE


func isInf*(value: Value): bool =
    result = value.kind == ValueTypes.INF or value.kind == MINF


func isNan*(value: Value): bool =
    result = value.kind == ValueTypes.NAN


func isNum*(value: Value): bool =
    result = isInt(value) or isFloat(value) or isInf(value) or isNan(value)


func isObj*(value: Value): bool =
    result = value.kind == OBJECT


func isStr*(value: Value): bool =
    result = isObj(value) and value.obj.kind == ObjectTypes.STRING


func toBool*(value: Value): bool =
    result = value.boolValue


func toInt*(value: Value): int =
    result = value.intValue


func toFloat*(value: Value): float =
    result = value.floatValue


func typeName*(value: Value): string =
    case value.kind:
        of BOOL, NIL, DOUBLE, INTEGER, NAN, INF:
            result = ($value.kind).toLowerAscii()
        of MINF:
           result = "inf"
        of OBJECT:
            case value.obj.kind:
                of ObjectTypes.STRING:
                    result = cast[ptr String](value.obj)[].typeName()
                else:
                    result = value.obj[].typeName()


func toStr*(value: Value): string =
    var strObj = cast[ptr String](value.obj)
    var c = ""
    for i in 0..strObj[].str.len - 1:
        c = &"{strObj[].str[i]}"
        result = result & c


func asInt*(n: int): Value =
    result = Value(kind: INTEGER, intValue: n)


func asFloat*(n: float): Value =
    result = Value(kind: DOUBLE, floatValue: n)


func asBool*(b: bool): Value =
    result = Value(kind: BOOL, boolValue: b)



proc asStr*(s: string): Value =
    result = Value(kind: OBJECT, obj: newString(s))


func isFalsey*(value: Value): bool =
    case value.kind:
        of BOOL:
            result = not value.toBool()
        of OBJECT:
            result = isFalsey(value.obj[])
        of INTEGER:
            result = value.toInt() == 0
        of DOUBLE:
            result = value.toFloat() > 0.0
        of NIL:
            result = true
        of INF, MINF:
            result = false
        of NAN:
            result = true


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
                        result = valuesEqual(a[], b[])
                    else:
                        result = valuesEqual(a.obj[], b.obj[])
            of INF:
                result = b.kind == INF
            of MINF:
                result = b.kind == MINF
            of NAN:
                result = false


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
                    result = hash(cast[ptr String](value.obj)[])
                else:
                    result = hash(value.obj[])
        else:   # More coming soon
            result = uint32 0
