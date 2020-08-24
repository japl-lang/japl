# This module represents the generic interface that JAPL uses internally
# to represent types. Small-sized entities such as numbers and booleans are
# treated differently with respect to bigger and more complex ones such as
# strings and functions. That is because, at least when we have our own GC,
# those more complex entities will be allocated on the heap, while the simpler
# ones will live on the stack

import ../types/objecttype
import ../types/stringtype
import strformat
import strutils


type
    ValueTypes* = enum   # All possible value types (this is the VM's notion of 'type', not the end user's)
        INTEGER, DOUBLE, BOOL, NIL, OBJECT
    Value* = ref object
        case kind*: ValueTypes
            of INTEGER:
                intValue*: int
            of DOUBLE:
                floatValue*: float
            of BOOL:
                boolValue*: bool
            of NIL:
                discard
            of OBJECT:
                obj*: Obj
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


func isNum*(value: Value): bool =
    result = isInt(value) or isFloat(value)


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
        of BOOL, NIL, DOUBLE, INTEGER:
            result = ($value.kind).toLowerAscii()
        of OBJECT:
            case value.obj.kind:
                of ObjectTypes.STRING:
                    result = cast[String](value.obj).typeName()
                else:
                    result = value.obj.typeName()


func toStr*(value: Value): string =
    var strObj = cast[String](value.obj)
    var c = ""
    result = ""
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
            result = stringify(value.obj)


func isFalsey*(value: Value): bool =
    case value.kind:
        of BOOL:
            result = not value.toBool()
        of OBJECT:
            result = isFalsey(value.obj)
        of INTEGER:
            result = value.toInt() == 0
        of DOUBLE:
            result = value.toFloat() > 0.0
        of NIL:
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
                        var a = cast[String](a.obj)
                        var b = cast[String](b.obj)
                        result = valuesEqual(a, b)
                    else:
                        result = valuesEqual(a.obj, b.obj)
