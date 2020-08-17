# Value objects and types representation
import ../types/objecttype


type
    ValueTypes* = enum
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


proc initValueArray*(): ValueArray =
    result = ValueArray(values: @[])


proc writeValueArray*(arr: var ValueArray, value: Value) =
    arr.values.add(value)


proc isNil*(value: Value): bool =
    return value.kind == NIL


proc isBool*(value: Value): bool =
    return value.kind == BOOL


proc isInt*(value: Value): bool =
    return value.kind == INTEGER


proc isFloat*(value: Value): bool =
    return value.kind == DOUBLE


proc isNum*(value: Value): bool =
    return isInt(value) or isFloat(value)


proc isObj*(value: Value): bool =
    return value.kind == OBJECT


proc toBool*(value: Value): bool =
    return value.boolValue


proc toInt*(value: Value): int =
    return value.intValue


proc toFloat*(value: Value): float =
    return value.floatValue


proc stringify*(value: Value): string =
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

proc `$`*(value: Value): string =
    result = stringify(value)


proc isFalsey*(value: Value): bool =
    case value.kind:
        of BOOL:
            return not value.toBool()
        of OBJECT:
            return isFalsey(value.obj)
        of INTEGER:
            return value.toInt() == 0
        of DOUBLE:
            return value.toFloat() > 0.0
        of NIL:
            return true


proc valuesEqual*(a: Value, b: Value): bool =
    if a.kind != b.kind:
        return false
    case a.kind:
        of BOOL:
            return a.toBool() == b.toBool()
        of NIL:
            return true
        of INTEGER:
            return a.toInt() == b.toInt()
        of DOUBLE:
            return a.toFloat() == b.toFloat()
        of OBJECT:
            return valuesEqual(a.obj, b.obj)
