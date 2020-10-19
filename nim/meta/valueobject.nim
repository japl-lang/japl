## This module represents the generic interface that JAPL uses internally
## to represent types. Small-sized entities such as numbers and booleans are
## treated differently with respect to bigger and more complex ones such as
## strings and functions. That is because those more comolex entities are
## allocated on the heap, while the simpler ones live on the stack

# import ../types/functiontype
import ../types/objecttype
import ../types/stringtype
import strformat


type
    ValueType* {.pure.} = enum
      # All possible value types (this is the VM's notion of 'type', not the end user's)
      Integer, Double, Bool, Nil, Object, Nan, Inf, Minf
    Value* = object
        ## Represents an internal JAPL type
        case kind*: ValueType
            of ValueType.Integer:
                intValue*: int
            of ValueType.Double:
                floatValue*: float
            of ValueType.Bool:
                boolValue*: bool
            of ValueType.Nil, ValueType.Inf, ValueType.Nan, ValueType.Minf:
                discard
            of ValueType.Object:
                obj*: ptr Obj

    ValueArray* = ref object
        values*: seq[Value]


func newValueArray*(): ValueArray =
    ## Creates a new ValueArray
    result = ValueArray(values: @[])


func writeValueArray*(arr: var ValueArray, value: Value) =
    ## Adds a value to a ValueArray object
    arr.values.add(value)


func isNil*(value: Value): bool =
    ## Returns true if the given value
    ## is a JAPL nil object
    result = value.kind == ValueType.Nil


func isBool*(value: Value): bool =
    ## Returns true if the given value
    ## is a JAPL bool
    result = value.kind == ValueType.Bool


func isInt*(value: Value): bool =
    ## Returns true if the given value
    ## is a JAPL integer
    result = value.kind == ValueType.Integer


func isFloat*(value: Value): bool =
    ## Returns true if the given value
    ## is a JAPL float
    result = value.kind == ValueType.Double


func isInf*(value: Value): bool =
    ## Returns true if the given value
    ## is a JAPL inf object
    result = value.kind == ValueType.Inf or value.kind == ValueType.Minf


func isNan*(value: Value): bool =
    ## Returns true if the given value
    ## is a JAPL nan object
    result = value.kind == ValueType.Nan


func isNum*(value: Value): bool =
    ## Returns true if the given value is
    ## either a JAPL number, nan or inf
    result = isInt(value) or isFloat(value) or isInf(value) or isNan(value)


func isObj*(value: Value): bool =
    ## Returns if the current value is a JAPL object
    result = value.kind == ValueType.Object


func isStr*(value: Value): bool =
    ## Returns true if the given object is a JAPL string
    result = isObj(value) and value.obj.kind == ObjectType.String


func toBool*(value: Value): bool =
    ## Converts a JAPL bool to a nim bool
    result = value.boolValue


func toInt*(value: Value): int =
    ## Converts a JAPL int to a nim int
    result = value.intValue


func toFloat*(value: Value): float =
    ## Converts a JAPL float to a nim float
    result = value.floatValue


func toStr*(value: Value): string =
    ## Converts a JAPL string into a nim string
    var strObj = cast[ptr String](value.obj)
    for i in 0..strObj.str.len - 1:
        result.add(strObj.str[i])


func asInt*(n: int): Value =
    ## Creates an int object
    result = Value(kind: ValueType.Integer, intValue: n)


func asFloat*(n: float): Value =
    ## Creates a float object (double)
    result = Value(kind: ValueType.Double, floatValue: n)


func asBool*(b: bool): Value =
    ## Creates a boolean object
    result = Value(kind: ValueType.Bool, boolValue: b)


proc asStr*(s: string): Value =
    ## Creates a string object
    result = Value(kind: ValueType.Object, obj: newString(s))