# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Base structure for values and objects in JAPL, all
## types inherit from this simple structure

import tables

type
    Chunk* = ref object
        ## A piece of bytecode.
        ## Consts represents the constants the code is referring to
        ## Code represents the bytecode
        ## Lines represents which lines the corresponding bytecode was one (1 to 1 correspondence)
        consts*: seq[Value]
        code*: seq[uint8]
        lines*: seq[int]
        
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

    ObjectType* {.pure.} = enum
        ## All the possible object types
        String, Exception, Function,
        Class, Module, BaseObject
    Obj* = object of RootObj
        # The object that rules them all
        kind*: ObjectType
        hashValue*: uint32
    String* = object of Obj    # A string object
        str*: ptr UncheckedArray[char]  # TODO -> Unicode support
        len*: int
    Integer* = object of Obj
        # An integer object
        intValue: int  # TODO: Bignum arithmetic
    Float* = object of Obj
        # A float object
        floatValue: float
    JAPLInf* = object of Float   # Inf is considered a float
    JAPLNan* = object of Obj     # While (logically) NaN is a separate type altogether
    Function* = object of Obj
        name*: ptr String
        arity*: int
        optionals*: int
        defaults*: Table[string, Obj]
        chunk*: Chunk
    JAPLException* = object of Obj
        errName*: ptr String
        message*: ptr String


proc `convert`(a: ptr Obj): ptr Obj =
    ## Performs conversions from a JAPL
    ## supertype to a subtype
    
    case a.kind:
        of ObjectType.String:
            result = cast[ptr String](a)
        of ObjectType.Function:
            result = cast[ptr Function](a)
        of ObjectType.Class, ObjectType.Module, ObjectType.BaseObject:
            discard  # TODO: Implement
        else:
            raise newException(Exception, "Attempted JAPL type conversion with unknown source object")


proc objType*(obj: ptr Obj): ObjectType =
    ## Returns the type of the object
    return obj.kind


proc stringify*(obj: ptr Obj): string =
    ## Returns a string representation
    ## of the object
    if obj.kind != ObjectType.BaseObject:    # NOTE: Consider how to reduce the boilerplate
        var newObj = convert obj
        result = newObj.stringify()
    else:
        result = "<object (built-in type)>"


proc typeName*(obj: ptr Obj): string =
    ## This method should return the
    ## name of the object type
    if obj.kind != ObjectType.BaseObject:
        var newObj = convert obj
        result = newObj.typeName()
    else:
        result = "object"



proc bool*(obj: ptr Obj): bool =
    ## Returns wheter the object should
    ## be considered a falsey value
    ## or not. Returns true if the
    ## object is truthy, or false
    ## if it is falsey
    if obj.kind != ObjectType.BaseObject:
        var newObj = convert obj
        result = newObj.bool()
    else:
        result = false


proc eq*(a: ptr Obj, b: ptr Obj): bool =
    ## Compares two objects for equality
    
    if a.kind != ObjectType.BaseObject:
        var newObj = convert(a)
        result = newObj.eq(b)
    else:
        result = a.kind == b.kind


proc hash*(self: ptr Obj): uint32 =
    # TODO: Make this actually useful
    result = 2166136261u32


proc add(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self + other
    ## or nil if the operation is unsupported
    result = nil  # Not defined for base objects!


proc sub(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self - other
    ## or nil if the operation is unsupported
    result = nil


proc mul(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self * other
    ## or nil if the operation is unsupported
    result = nil


proc trueDiv(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self / other
    ## or nil if the operation is unsupported
    result = nil


proc exp(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ** other
    ## or nil if the operation is unsupported
    result = nil


proc binaryAnd(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self & other
    ## or nil if the operation is unsupported
    result = nil


proc binaryOr(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self | other
    ## or nil if the operation is unsupported
    result = nil


proc binaryNot(self: ptr Obj): ptr Obj =
    ## Returns the result of ~self
    ## or nil if the operation is unsupported
    result = nil


proc binaryXor(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ^ other
    ## or nil if the operation is unsupported
    result = nil

    
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

func asValue*(obj: ptr Obj): Value =
    ## Creates a Value object of ValueType.Object as type and obj (arg 1) as
    ## contained obj

    result = Value(kind: ValueType.Object, obj: obj)


