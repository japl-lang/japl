# Value objects and types representation


type
    ValueTypes* = enum
        INTEGER, DOUBLE, BOOL, NIL, OBJECT
    ObjectTypes* = enum
        STRING,
    Obj* = ref object
        case kind*: ObjectTypes
            of STRING:
                str*: string
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


proc stringifyObject(obj: Obj): string =
    case obj.kind:
        of STRING:
            return obj.str


proc stringifyValue*(value: Value): string =
    case value.kind:
        of INTEGER:
            result = $value.intValue
        of DOUBLE:
            result = $value.floatValue
        of BOOL:
            result = $value.boolValue
        of NIL:
            result = "nil"
        of OBJECT:
            result = stringifyObject(value.obj)

