# Value objects
import strformat

type
    ValueTypes* = enum
        FLOAT, INT, BOOL, NIL, OBJECT
    ObjectTypes* = enum
        STRING,
    Obj* = ref object
        case kind*: ObjectTypes
            of STRING:
                str*: string
    Value* = ref object
        case kind*: ValueTypes
            of FLOAT:
                floatValue*: float
            of INT:
                intValue*: int
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


proc stringifyObject(obj: Obj): string =
    case obj.kind:
        of STRING:
            return obj.str


proc stringifyValue*(value: Value): string =
    case value.kind:
        of FLOAT:
            result = $value.floatValue
        of INT:
            result = $value.intValue
        of BOOL:
            result = $value.boolValue
        of NIL:
            result = "none"
        of OBJECT:
            result = stringifyObject(value.obj)

