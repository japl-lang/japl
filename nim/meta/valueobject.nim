# This module represents the generic interface that JAPL uses internally
# to represent types. Small-sized entities such as numbers and booleans are
# treated differently with respect to bigger and more complex ones such as
# strings and functions. That is because those more comolex entities are
# allocated on the heap, while the simpler ones live on the stack

# import ../types/functiontype
import ../types/objecttype
import ../types/stringtype
import strformat


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


func toStr*(value: Value): string =
    var strObj = cast[ptr String](value.obj)
    var c = ""
    for i in 0..strObj.str.len - 1:
        c = &"{strObj.str[i]}"
        result = result & c


func asInt*(n: int): Value =
    result = Value(kind: INTEGER, intValue: n)


func asFloat*(n: float): Value =
    result = Value(kind: DOUBLE, floatValue: n)


func asBool*(b: bool): Value =
    result = Value(kind: BOOL, boolValue: b)



proc asStr*(s: string): Value =
    result = Value(kind: OBJECT, obj: newString(s))
