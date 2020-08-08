# Value objects
import strformat

type
    ValueTypes* = enum
        FLOAT, INT, CHAR, STRING
    Value* = ref object of RootObj
        case kind*: ValueTypes
            of CHAR:
                charValue*: char
            of STRING:
                stringValue*: string
            of FLOAT:
                floatValue*: float
            of INT:
                intValue*: int
    ValueArray* = ref object
        values*: seq[Value]


proc initValueArray*(): ValueArray =
    result = ValueArray(values: @[])


proc writeValueArray*(arr: var ValueArray, value: Value) =
    arr.values.add(value)


proc stringifyValue*(value: Value): string =
    case value.kind:
        of FLOAT:
            result = $value.floatValue
        of STRING:
            result = value.stringValue
        of INT:
            result = $value.intValue
        of CHAR:
            result = &"{value.charValue}"
