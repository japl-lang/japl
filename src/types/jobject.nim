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
import strformat


type
    NotImplementedError = object of CatchableError
        ## Raised when a given operation is unsupported
        ## on a given type
    Chunk* = ref object   # TODO: This shouldn't be here, but Function needs it. Consider refactoring
        ## A piece of bytecode.
        ## Consts represents the constants table the code is referring to
        ## Code is the compiled bytecode
        ## Lines maps bytecode instructions to line numbers (1 to 1 correspondence)
        consts*: seq[ptr Obj]
        code*: seq[uint8]
        lines*: seq[int]
    ObjectType* {.pure.} = enum
        ## All the possible object types
        String, Exception, Function,
        Class, Module, BaseObject,
        Integer, Float, Bool, NotANumber,
        Infinity, Nil
    Obj* = object of RootObj
        ## The base object for all
        ## JAPL types. Every object
        ## in JAPL implicitly inherits
        ## from this base type
        kind*: ObjectType
        hashValue*: uint64
    String* = object of Obj
        ## A string object
        str*: ptr UncheckedArray[char]  # TODO -> Unicode support
        len*: int
    Integer* = object of Obj
        ## An integer object
        intValue: int  # TODO: Bignum arithmetic
    Bool* = object of Integer
        ## A boolean object
        boolValue: bool  # If the boolean is true or false
    Nil* = object of Bool
        ## A nil object
    Float* = object of Integer
        ## A float object
        floatValue: float
    Infinity* = object of Float   # Inf is considered a float
        ## An inf object
        isNegative: bool  # This differentiates inf and -inf
    NotANumber* = object of Float     # NaN is as well (IEEE 754)
        ## A nan object
    Function* = object of Obj
        ## A function objecy
        name*: ptr String
        arity*: int    # The number of required parameters
        optionals*: int   # How many optional parameters
        defaults*: seq[ptr Obj]   # List of default arguments, in order
        chunk*: Chunk   # The function's body
    JAPLException* = object of Obj    # TODO: Create exceptions subclasses
        ## The base exception object
        errName*: ptr String    # TODO: Ditch error name in favor of inheritance-based types
        message*: ptr String


## Object constructors and allocators

proc allocateObject*(size: int, kind: ObjectType): ptr Obj =
    ## Wrapper around memory.reallocate to create a new generic JAPL object
    result = cast[ptr Obj](reallocate(nil, 0, size))
    result.kind = kind


template allocateObj*(kind: untyped, objType: ObjectType): untyped =
    ## Wrapper around allocateObject to cast a generic object
    ## to a more specific type
    cast[ptr kind](allocateObject(sizeof kind, objType))


proc newChunk*(): Chunk =
    ## Initializes a new, empty chunk
    result = Chunk(consts: @[], code: @[], lines: @[])


proc objType*(obj: ptr Obj): ObjectType =
    ## Returns the type of the object
    return obj.kind


## Utilities that bridge nim and JAPL types

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
    result = obj.kind == ObjectType.NotANumber


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
    ## Converts a nim int into a JAPL int
    result = allocateObj(Integer, ObjectType.Integer)
    result.intValue = n


proc asFloat*(n: float): ptr Float =
    ## Converts a nim float into a JAPL float
    result = allocateObj(Float, ObjectType.Float)
    result.floatValue = n


proc asBool*(b: bool): ptr Bool =
    ## Converts a nim bool into a JAPL bool
    result = allocateObj(Bool, ObjectType.Bool)
    result.boolValue = b


proc asNil*(): ptr Nil = 
    ## Creates a nil object
    result = allocateObj(Nil, ObjectType.Nil)


proc asNan*(): ptr NotANumber = 
    ## Creates a nan object
    result = allocateObj(NotANumber, ObjectType.NotANumber)


proc asInf*(): ptr Infinity =
    ## Creates an inf object
    result = allocateObj(Infinity, ObjectType.Infinity)


proc newObj*(): ptr Obj =
    ## Allocates a generic JAPL object
    result = allocateObj(Obj, ObjectType.BaseObject)


## JAPL procs implementations below

# Implementations for typeName

proc typeName*(self: ptr Obj): string =
    ## Returns the name of the object type
    result = "object"

proc typeName*(self: ptr Function): string =
    result = "function"

proc typeName*(self: ptr String): string =
    return "string"

proc typeName*(self: ptr Integer): string =
    result = "integer"

proc typeName*(self: ptr Float): string = 
    result = "float"

proc typeName*(self: ptr Bool): string = 
    result = "bool"

# Implementations for stringify

proc stringify*(self: ptr Integer): string =
    result = $self.intValue


proc stringify*(self: ptr String): string =
    result = ""
    for i in 0..<self.len:
        result = result & (&"{self.str[i]}")


proc stringify*(self: ptr Float): string =
    result = $self.floatValue


proc stringify*(self: ptr Bool): string =
    result = $self.boolValue


proc stringify(self: ptr NotANumber): string =
    result = "nan"


proc stringify(self: ptr Infinity): string =
    if self.isNegative:
        result = "-inf"
    else:
        result = "inf"

proc stringify(self: ptr Nil): string =
    result = "nil"


proc stringify*(self: ptr JAPLException): string =
    result = &"{self.errName.stringify()}: {self.message.stringify()}"


proc stringify*(self: ptr Function): string =
    if self.name != nil:
        result = &"<function {self.name.stringify()}>"
    else:
        result = "<code object>"

proc stringify*(self: ptr Obj): string = 
    ## Returns a string representation of the
    ## given object
    case self.kind:
        of ObjectType.BaseObject:
            result = "<object>"
        of ObjectType.String:
            result = cast[ptr String](self).stringify()
        of ObjectType.Integer:
            result = cast[ptr Integer](self).stringify()
        of ObjectType.Float:
            result = cast[ptr Float](self).stringify()
        of ObjectType.Bool:
            result = cast[ptr Bool](self).stringify()
        of ObjectType.Function:
            result = cast[ptr Function](self).stringify()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).stringify()
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).stringify()
        of ObjectType.Nil:
            result = cast[ptr Nil](self).stringify()
        else:
            discard  # TODO


# Implementations for isFalsey


proc isFalsey(self: ptr String): bool =
    result = self.len == 0


proc isFalsey(self: ptr Function): bool =
    result = false


proc isFalsey(self: ptr Integer): bool =
    result = self.intValue == 0


proc isFalsey(self: ptr Float): bool =
    result = self.floatValue == 0.0


proc isFalsey(self: ptr Bool): bool = 
    result = not self.boolValue


proc isFalsey(self: ptr Infinity): bool = 
    result = false


proc isFalsey(self: ptr NotANumber): bool =
    result = true


proc isFalsey(self: ptr Nil): bool =
    result = true


proc isFalsey*(self: ptr Obj): bool =
    ## Returns true if the object is
    ## falsey, true otherwise
    case self.kind:
        of ObjectType.BaseObject:
            result = false
        of ObjectType.String:
            result = cast[ptr String](self).isFalsey()
        of ObjectType.Integer:
            result = cast[ptr Integer](self).isFalsey()
        of ObjectType.Float:
            result = cast[ptr Float](self).isFalsey()
        of ObjectType.Bool:
            result = cast[ptr Bool](self).isFalsey()
        of ObjectType.Function:
            result = cast[ptr Function](self).isFalsey()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).isFalsey()
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).isFalsey()
        of ObjectType.Nil:
            result = cast[ptr Nil](self).isFalsey()
        else:
            discard  # TODO

# Implementation for hash

proc hash(self: ptr String): uint64 =
    result = 2166136261u
    var i = 0
    while i < self.len:
        result = result xor uint64 self.str[i]
        result *= 16777619
        i += 1
    return result

proc hash(self: ptr Float): uint64 =
    result = 2166136261u xor uint64 self.floatValue   # TODO: Improve this
    result *= 16777619


proc hash(self: ptr Infinity): uint64 =
    # TODO: Arbitrary hash seems a bad idea
    if self.isNegative:
        result = 1u
    else:
        result = 0u


proc hash(self: ptr NotANumber): uint64 =
    # TODO: Hashable?
    raise newException(NotImplementedError, "unhashable type 'nan'")


proc hash(self: ptr Nil): uint64 =
    # TODO: Arbitrary hash seems a bad idea
    result = 2u

proc hash(self: ptr Function): uint64 = 
    # TODO: Hashable?
    raise newException(NotImplementedError, "unhashable type 'function'")


proc hash*(self: ptr Obj): uint64 =
    ## Returns the hash of the object using
    ## the FNV-1a algorithm (or a predefined value).
    ## Raises an error if the object is not hashable
    case self.kind:
        of ObjectType.BaseObject:
            result = 2166136261u  # Constant hash
        of ObjectType.String:
            result = cast[ptr String](self).hash()
        of ObjectType.Integer:
            result = cast[ptr Integer](self).hash()
        of ObjectType.Float:
            result = cast[ptr Float](self).hash()
        of ObjectType.Bool:
            result = cast[ptr Bool](self).hash()
        of ObjectType.Function:
            result = cast[ptr Function](self).hash()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).hash()
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).hash()
        of ObjectType.Nil:
            result = cast[ptr Nil](self).hash()
        else:
            discard  # TODO


# Implementation for eq

proc eq(self, other: ptr String): bool =
    if self.len != other.len:
        return false
    elif self.hash != other.hash:
        return false
    for i in 0..self.len - 1:
        if self.str[i] != other.str[i]:
            return false
    result = true


proc eq(self, other: ptr Integer): bool =
    result = self.intValue == other.intValue


proc eq(self, other: ptr Float): bool =
    result = self.floatValue == other.floatValue


proc eq(self, other: ptr Bool): bool =
    result = self.boolValue == other.boolValue


proc eq(self, other: ptr Function): bool =
    result = self.name.stringify() == other.name.stringify()


proc eq(self, other: ptr NotANumber): bool =
    result = false


proc eq(self, other: ptr Nil): bool =
    result = true


proc eq(self, other: ptr Infinity): bool =
    result = self.isNegative == other.isNegative


proc eq*(self, other: ptr Obj): bool =
    ## Compares two objects for equality,
    ## returns true if self equals other
    ## and false otherwise
    if self.kind != other.kind:
        return false
    case self.kind:
        of ObjectType.BaseObject:
            result = other.kind == ObjectType.BaseObject
        of ObjectType.String:
            var self = cast[ptr String](self)
            var other = cast[ptr String](other)
            result = self.eq(other)
        of ObjectType.Integer:
            var self = cast[ptr Integer](self)
            var other = cast[ptr Integer](other)
            result = self.eq(other)
        of ObjectType.Float:
            var self = cast[ptr Float](self)
            var other = cast[ptr Float](other)
            result = self.eq(other)
        of ObjectType.Bool:
            var self = cast[ptr Bool](self)
            var other = cast[ptr Bool](other)
            result = self.eq(other)
        of ObjectType.Function:
            var self = cast[ptr Function](self)
            var other = cast[ptr Function](other)
            result = self.eq(other)
        else:
            discard  # TODO


## String constructors and converters

proc newString*(str: string): ptr String =
    # TODO -> Unicode
    result = allocateObj(String, ObjectType.String)
    result.str = allocate(UncheckedArray[char], char, len(str))
    for i in 0..len(str) - 1:
        result.str[i] = str[i]
    result.len = len(str)
    result.hashValue = result.hash()

proc asStr*(s: string): ptr Obj =
    ## Converts a nim string into a 
    ## JAPL string
    result = newString(s)

# End of string object procs


# Functions constructors and procedures

type
    FunctionType* {.pure.} = enum
        ## All code in JAPL is compiled
        ## as if it was inside some sort
        ## of function. To differentiate
        ## between actual functions and
        ## the top-level code, this tiny
        ## enum is used to tell the two
        ## contexts apart when compiling
        Func, Script


proc newFunction*(name: string = "", chunk: Chunk = newChunk(), arity: int = 0): ptr Function =
    ## Allocates a new function object with the given
    ## bytecode chunk and arity. If the name is an empty string
    ## (the default), the function will be an
    ## anonymous code object
    # TODO: Add lambdas
    # TODO: Add support for optional parameters
    result = allocateObj(Function, ObjectType.Function)
    if name.len > 1:
        result.name = newString(name)
    else:
        result.name = nil
    result.arity = arity
    result.chunk = chunk


proc bool*(obj: ptr Obj): bool =
    ## Returns wheter the object should
    ## be considered a falsey obj
    ## or not. Returns true if the
    ## object is truthy, or false
    ## if it is falsey
    result = false


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

proc newIndexError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("IndexError")
    result.message = newString(message)


proc newReferenceError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("ReferenceError")
    result.message = newString(message)


proc newInterruptedError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("InterruptedError")
    result.message = newString(message)


proc newRecursionError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("RecursionError")
    result.message = newString(message)



proc newTypeError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("TypeError")
    result.message = newString(message)
