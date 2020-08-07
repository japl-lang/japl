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

proc printValue*(value: Value) =
    case value.kind:
        of FLOAT:
            echo &"\tValue: {value.floatValue}\n\tKind: {value.kind}"
        of STRING:
            echo &"\tValue: {value.stringValue}\n\tKind: {value.kind}"
        of INT:
            echo &"\tValue: {value.intValue}\n\tKind: {value.kind}"
        of CHAR:
            echo &"\tValue: {value.charValue}\n\tKind: {value.kind}"

