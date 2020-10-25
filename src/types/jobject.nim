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

## Base structure for objects in JAPL, all
## types inherit from this simple structure

import ../memory


type
    Chunk* = ref object
        ## A piece of bytecode.
        ## Consts represents the constants the code is referring to
        ## Code represents the bytecode
        ## Lines represents which lines the corresponding bytecode was one (1 to 1 correspondence)
        consts*: seq[ptr Obj]
        code*: seq[uint8]
        lines*: seq[int]
    ObjectType* {.pure.} = enum
        ## All the possible object types
        String, Exception, Function,
        Class, Module, BaseObject,
        Integer, Float, Bool, Nan,
        Infinity, Nil
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
    Bool* = object of Integer
        boolValue: bool  # If the boolean is true or false
    Nil* = object of Bool
    Float* = object of Integer
        # A float object
        floatValue: float
    Infinity* = object of Float   # Inf is considered a float
        isNegative: bool  # This differentiates inf and -inf
    NotANumber* = object of Float     # NaN is as well (IEEE 754)
    Function* = object of Obj
        name*: ptr String
        arity*: int
        optionals*: int
        defaults*: seq[ptr Obj]
        chunk*: Chunk
    JAPLException* = object of Obj
        errName*: ptr String
        message*: ptr String


proc `convert`*(a: ptr Obj): ptr Obj =
    ## Performs conversions from a JAPL
    ## supertype to a subtype
    
    case a.kind:
        of ObjectType.String:
            result = cast[ptr String](a)
        of ObjectType.Function:
            result = cast[ptr Function](a)
        of ObjectType.Integer:
            result = cast[ptr Integer](a)
        of ObjectType.Float:
            result = cast[ptr Float](a)
        of ObjectType.Bool:
            result = cast[ptr Bool](a)
        of ObjectType.Nan:
            result = cast[ptr NotANumber](a)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](a)
        of ObjectType.BaseObject:
            result = cast[ptr Obj](a)
        of ObjectType.Class, ObjectType.Module:
            discard  # TODO: Implement
        else:
            raise newException(Exception, "Attempted JAPL type conversion with unknown source object")



proc allocateObject*(size: int, kind: ObjectType): ptr Obj =
    ## Wrapper around reallocate to create a new generic JAPL object
    result = cast[ptr Obj](reallocate(nil, 0, size))
    result.kind = kind


template allocateObj*(kind: untyped, objType: ObjectType): untyped =
    ## Wrapper around allocateObject to cast a generic object
    ## to a more specific type
    cast[ptr kind](allocateObject(sizeof kind, objType))


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


proc isFalsey*(obj: ptr Obj): bool =
    ## Returns true if the given
    ## object is falsey
    if obj.kind != ObjectType.BaseObject:    # NOTE: Consider how to reduce the boilerplate
        var newObj = convert obj
        result = newObj.isFalsey()
    else:
        result = false


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
    ## be considered a falsey obj
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
    if self.kind == ObjectType.BaseObject:
        result = 2166136261u32
    else:
        result = convert(self).hash()


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

    
proc isNil*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL nil object
    result = obj.kind == ObjectType.Nil


proc isBool*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL bool
    result = obj.kind == ObjectType.Bool


proc isInt*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL integer
    result = obj.kind == ObjectType.Integer


proc isFloat*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL float
    result = obj.kind == ObjectType.Float


proc isInf*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL inf object
    result = obj.kind == ObjectType.Infinity


proc isNan*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL nan object
    result = obj.kind == ObjectType.Nan


proc isNum*(obj: ptr Obj): bool =
    ## Returns true if the given obj is
    ## either a JAPL number, nan or inf
    result = isInt(obj) or isFloat(obj) or isInf(obj) or isNan(obj)


proc isStr*(obj: ptr Obj): bool =
    ## Returns true if the given object is a JAPL string
    result = obj.kind == ObjectType.String


proc toBool*(obj: ptr Obj): bool =
    ## Converts a JAPL bool to a nim bool
    result = cast[ptr Bool](obj).boolValue


proc toInt*(obj: ptr Obj): int =
    ## Converts a JAPL int to a nim int
    result = cast[ptr Integer](obj).intValue


proc toFloat*(obj: ptr Obj): float =
    ## Converts a JAPL float to a nim float
    result = cast[ptr Float](obj).floatValue

# TODO ambiguous naming: conflict with toString(obj: obj) that does JAPL->JAPL
proc toStr*(obj: ptr Obj): string =
    ## Converts a JAPL string into a nim string
    var strObj = cast[ptr String](obj)
    for i in 0..strObj.str.len - 1:
        result.add(strObj.str[i])


proc asInt*(n: int): ptr Integer =
    ## Creates an int object
    result = allocateObj(Integer, ObjectType.Integer)
    result.intValue = n


proc asFloat*(n: float): ptr Float =
    ## Creates a float object (double)
    result = allocateObj(Float, ObjectType.Float)
    result.floatValue = n


proc asBool*(b: bool): ptr Bool =
    ## Creates a boolean object
    result = allocateObj(Bool, ObjectType.Bool)
    result.boolValue = b


proc asNil*(): ptr Nil = 
    ## Creates a nil object
    result = allocateObj(Nil, ObjectType.Nil)


proc asNan*(): ptr NotANumber = 
    ## Creates a nil object
    result = allocateObj(NotANumber, ObjectType.Nan)


proc asInf*(): ptr Infinity = 
    ## Creates a nil object
    result = allocateObj(Infinity, ObjectType.Infinity)


proc asObj*(obj: ptr Obj): ptr Obj =
    ## Creates a generic JAPL object
    result = allocateObj(Obj, ObjectType.BaseObject)


