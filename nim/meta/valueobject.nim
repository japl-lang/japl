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
  result = ValueArray(values: @[])


func writeValueArray*(arr: var ValueArray, value: Value) =
  ## Adds a value to a valuearray
  arr.values.add(value)


func isNil*(value: Value): bool =
  result = value.kind == ValueType.Nil


func isBool*(value: Value): bool =
  result = value.kind == ValueType.Bool


func isInt*(value: Value): bool =
  result = value.kind == ValueType.Integer


func isFloat*(value: Value): bool =
  result = value.kind == ValueType.Double


func isInf*(value: Value): bool =
  result = value.kind == ValueType.Inf or value.kind == ValueType.Minf


func isNan*(value: Value): bool =
  result = value.kind == ValueType.Nan


func isNum*(value: Value): bool =
  result = isInt(value) or isFloat(value) or isInf(value) or isNan(value)


func isObj*(value: Value): bool =
  result = value.kind == ValueType.Object


func isStr*(value: Value): bool =
  result = isObj(value) and value.obj.kind == ObjectType.String


func toBool*(value: Value): bool =
  result = value.boolValue


func toInt*(value: Value): int =
  result = value.intValue


func toFloat*(value: Value): float =
  result = value.floatValue


func toStr*(value: Value): string =
  var strObj = cast[ptr String](value.obj)
  for i in 0..strObj.str.len - 1:
    result.add(strObj.str[i])


func asInt*(n: int): Value =
  ## creates a value of type int
  result = Value(kind: ValueType.Integer, intValue: n)


func asFloat*(n: float): Value =
  ## creates a value of type float
  result = Value(kind: ValueType.Double, floatValue: n)


func asBool*(b: bool): Value =
  ## creates a value of type bool
  result = Value(kind: ValueType.Bool, boolValue: b)

proc asStr*(s: string): Value =
  ## creates a value of type string(object)
  result = Value(kind: ValueType.Object, obj: newString(s))
