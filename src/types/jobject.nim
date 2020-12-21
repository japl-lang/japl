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

## The JAPL's type system. In JAPL, all entities are
## objects, and are always references to a memory location
## somewhere in the heap

import ../memory
import strformat
import math
import bitops
import strutils


type
    NotImplementedError* = object of CatchableError
        ## Raised when a given operation is unsupported
        ## on a given type
    Chunk* = ref object   # TODO: This shouldn't be here, but Function needs it. Consider refactoring
        ## A piece of bytecode.
        ## Consts represents the constants table the code is referring to
        ## Code is the compiled bytecode
        ## Lines maps bytecode instructions to line numbers (1 to 1 correspondence)
        consts*: seq[ptr Obj]
        code*: seq[uint8]
        lines*: seq[int]   # TODO: Run-length encoding
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
        isHashable: bool   # This is false for unhashable objects
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


# Custom operators
proc `**`(a, b: int): int = pow(a.float, b.float).int
proc `**`(a, b: float): float = pow(a, b)


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


## Utilities that bridge nim and JAPL types or to inspect
## JAPL objects


proc objType*(obj: ptr Obj): ObjectType =
    ## Returns the type of the object
    result = obj.kind


proc isCallable*(obj: ptr Obj): bool =
    ## Returns true if the given object
    ## is callable, false otherwise
    result = obj.kind in {ObjectType.Function, ObjectType.Class}


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


proc toStr*(obj: ptr Obj): string =
    ## Converts a JAPL string into a nim string
    var strObj = cast[ptr String](obj)
    for i in 0..strObj.str.len - 1:
        result.add(strObj.str[i])


proc asInt*(n: int): ptr Integer =
    ## Converts a nim int into a JAPL int
    result = allocateObj(Integer, ObjectType.Integer)
    result.intValue = n
    result.isHashable = true


proc asFloat*(n: float): ptr Float =
    ## Converts a nim float into a JAPL float
    result = allocateObj(Float, ObjectType.Float)
    result.floatValue = n
    result.isHashable = true


proc asBool*(b: bool): ptr Bool =
    ## Converts a nim bool into a JAPL bool
    result = allocateObj(Bool, ObjectType.Bool)
    result.boolValue = b
    result.isHashable = true

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

proc hash(self: ptr String): uint64   # Forward declaration for asStr


proc asStr*(s: string): ptr String =
    ## Converts a nim string into a
    ## JAPL string
    result = allocateObj(String, ObjectType.String)
    result.str = allocate(UncheckedArray[char], char, len(s))
    for i in 0..len(s) - 1:
        result.str[i] = s[i]
    result.len = len(s)
    result.hashValue = result.hash()
    result.isHashable = true



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
        result.name = name.asStr()
    else:
        result.name = nil
    result.arity = arity
    result.chunk = chunk
    result.isHashable = false


proc newIndexError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "IndexError".asStr()
    result.message = message.asStr()


proc newReferenceError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "ReferenceError".asStr()
    result.message = message.asStr()


proc newInterruptedError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "InterruptedError".asStr()
    result.message = message.asStr()


proc newRecursionError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "RecursionError".asStr()
    result.message = message.asStr()



proc newTypeError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "TypeError".asStr()
    result.message = message.asStr()


## Exposed object methods used in the JAPL runtime
## are defined and implemented below


# Implementations for typeName

proc typeName(self: ptr Function): string =
    result = "function"


proc typeName(self: ptr String): string =
    return "string"


proc typeName(self: ptr Integer): string =
    result = "integer"


proc typeName(self: ptr NotANumber): string =
    result = "float"


proc typeName(self: ptr Float): string =
    result = "float"


proc typeName(self: ptr Infinity): string =
    result = "infinity"


proc typeName(self: ptr Nil): string =
    result = "nil"


proc typeName(self: ptr Bool): string =
    result = "bool"


proc typeName*(self: ptr Obj): string =
    ## Returns the name of the object's type
    case self.kind:
        of ObjectType.BaseObject:
            result = "object"
        of ObjectType.String:
            result = cast[ptr String](self).typeName()
        of ObjectType.Integer:
            result = cast[ptr Integer](self).typeName()
        of ObjectType.Float:
            result = cast[ptr Float](self).typeName()
        of ObjectType.Bool:
            result = cast[ptr Bool](self).typeName()
        of ObjectType.Function:
            result = cast[ptr Function](self).typeName()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).typeName()
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).typeName()
        of ObjectType.Nil:
            result = cast[ptr Nil](self).typeName()
        else:
            discard  # TODO


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
    if not self.isHashable:
        raise newException(NotImplementedError, &"unhashable type '{self.typeName}'")
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
    result = self.name.stringify() == other.name.stringify() # Since in JAPL functions cannot
    # be overridden, if two function names are equal they are also the same
    # function object (TODO: Verify this)


proc eq(self, other: ptr NotANumber): bool =
    result = false   # As per IEEE 754 spec, nan != nan


proc eq(self, other: ptr Nil): bool =
    result = true


proc eq(self, other: ptr Infinity): bool =
    result = self.isNegative == other.isNegative


proc eq*(self, other: ptr Obj): bool =
    ## Compares two objects for equality,
    ## returns true if self equals other
    ## and false otherwise
    if self.kind != other.kind:   # If the types are different it's not
    # even worth going any further (and you couldn't anyway)
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
        of ObjectType.Infinity:
            var self = cast[ptr Infinity](self)
            var other = cast[ptr Infinity](other)
            result = self.eq(other)
        of ObjectType.NotANumber:
            var self = cast[ptr NotANumber](self)
            var other = cast[ptr NotANumber](other)
            result = self.eq(other)
        of ObjectType.Nil:
            var self = cast[ptr Nil](self)
            var other = cast[ptr Nil](other)
            result = self.eq(other)
        else:
            discard  # TODO


proc negate(self: ptr Integer): ptr Integer =
    result = (-self.toInt()).asInt()


proc negate(self: ptr Float): ptr Float =
    result = (-self.toFloat()).asFloat()


proc negate(self: ptr Infinity): ptr Infinity =
    result = asInf()
    result.isNegative = true


proc negate*(self: ptr Obj): ptr Obj = 
    ## Returns the result of -self or
    ## raises an error if the operation
    ## is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).negate()
        of ObjectType.Float:
            result = cast[ptr Float](self).negate()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).negate()
        else:
            raise newException(NotImplementedError, &"unsupported unary operator '-' for object of type '{self.typeName()}'")


proc lt(self: ptr Integer, other: ptr Obj): bool =
    case other.kind: 
        of ObjectType.Integer:
            result = self.intValue < cast[ptr Integer](other).intValue
        of ObjectType.Float:
            result = (float self.intValue) < cast[ptr Float](other).floatValue
        of ObjectType.Infinity:
            let other = cast[ptr Infinity](other)
            if other.isNegative:
                result = false
            else:
                result = true
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '<' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc lt(self: ptr Float, other: ptr Obj): bool =
    case other.kind: 
        of ObjectType.Integer:
            result = self.floatValue < (float cast[ptr Integer](other).intValue)
        of ObjectType.Float:
            result = self.floatValue < cast[ptr Float](other).floatValue
        of ObjectType.Infinity:
            let other = cast[ptr Infinity](other)
            if other.isNegative:
                result = false
            else:
                result = true
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '<' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc lt(self: ptr Infinity, other: ptr Obj): bool =
    case other.kind: 
        of ObjectType.Integer:
            let other = cast[ptr Integer](other)
            if self.isNegative and other.intValue > 0:
                result = true
            else:
                result = false
        of ObjectType.Float:
            let other = cast[ptr Float](other)
            if self.isNegative and other.floatValue > 0.0:
                result = true
            else:
                result = false
        of ObjectType.Infinity:
            let other = cast[ptr Infinity](other)
            if other.isNegative and not self.isNegative:
                result = false
            else:
                result = false
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '<' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc lt*(self: ptr Obj, other: ptr Obj): bool = 
    ## Returns the result of self < other or
    ## raises an error if the operation
    ## is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).lt(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).lt(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).lt(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '<' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc gt(self: ptr Integer, other: ptr Obj): bool =
    case other.kind: 
        of ObjectType.Integer:
            result = self.intValue > cast[ptr Integer](other).intValue
        of ObjectType.Float:
            result = (float self.intValue) > cast[ptr Float](other).floatValue
        of ObjectType.Infinity:
            let other = cast[ptr Infinity](other)
            if other.isNegative:
                result = true
            else:
                result = false
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '>' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc gt(self: ptr Float, other: ptr Obj): bool =
    case other.kind: 
        of ObjectType.Integer:
            result = self.floatValue > (float cast[ptr Integer](other).intValue)
        of ObjectType.Float:
            result = self.floatValue > cast[ptr Float](other).floatValue
        of ObjectType.Infinity:
            let other = cast[ptr Infinity](other)
            if other.isNegative:
                result = true
            else:
                result = false
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '>' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc gt(self: ptr Infinity, other: ptr Obj): bool =
    case other.kind: 
        of ObjectType.Integer:
            let other = cast[ptr Integer](other)
            if self.isNegative and other.intValue > 0:
                result = false
            else:
                result = true
        of ObjectType.Float:
            let other = cast[ptr Float](other)
            if self.isNegative and other.floatValue > 0.0:
                result = false
            else:
                result = true
        of ObjectType.Infinity:
            let other = cast[ptr Infinity](other)
            if other.isNegative and not self.isNegative:
                result = true
            else:
                result = false
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '>' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc gt*(self: ptr Obj, other: ptr Obj): bool = 
    ## Returns the result of self < other or
    ## raises an error if the operation
    ## is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).gt(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).gt(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).gt(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '>' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sum(self: ptr Infinity, other: ptr Obj): ptr Infinity =
    result = asInf()
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.isNegative = true
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}' ")


proc sum(self: ptr NotANumber, other: ptr Obj): ptr NotANumber =
    result = asNan()
    case other.kind:
        of ObjectType.NotANumber, ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")



proc sum(self: ptr String, other: ptr Obj): ptr String =
    if other.kind == ObjectType.String:
        var other = cast[ptr String](other)
        var selfStr = self.toStr()
        var otherStr = other.toStr()
        result = (selfStr & otherStr).asStr()
    else:
        raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sum(self: ptr Integer, other: ptr Obj): ptr Obj =  # This can yield a float!
    case other.kind:
        of ObjectType.Integer:
            result = (self.toInt() + cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) + cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sum(self: ptr Float, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = (self.toFloat() + float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() + cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sum*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self + other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.String:    # Here we don't cast other (yet)
              # because binary operators can mix types together,
              # like in "hello" * 5, or 3.5 * 8. Casting that
              # later allows for finer error reporting and keeps
              # these methods as generic as possible
            result = cast[ptr String](self).sum(other)
        of ObjectType.Integer:
            result = cast[ptr Integer](self).sum(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).sum(other)
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).sum(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).sum(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sub(self: ptr Infinity, other: ptr Obj): ptr Infinity =
    result = asInf()
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.isNegative = true
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sub(self: ptr NotANumber, other: ptr Obj): ptr NotANumber =
    result = asNan()
    case other.kind:
        of ObjectType.NotANumber, ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")



proc sub(self: ptr Integer, other: ptr Obj): ptr Obj =  # This can yield a float!
    case other.kind:
        of ObjectType.Integer:
            result = (self.toInt() - cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) - cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sub(self: ptr Float, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = (self.toFloat() - float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() - cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc sub*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self - other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).sub(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).sub(other)
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).sub(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).sub(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc mul(self: ptr Infinity, other: ptr Obj): ptr Infinity =
    result = asInf()
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.isNegative = true
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '+' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc mul(self: ptr NotANumber, other: ptr Obj): ptr NotANumber =
    result = asNan()
    case other.kind:
        of ObjectType.NotANumber, ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '*' for objects of type '{self.typeName()}' and '{other.typeName()}'")



proc mul(self: ptr Integer, other: ptr Obj): ptr Obj =  # This can yield a float!
    case other.kind:
        of ObjectType.Integer:
            result = (self.toInt() * cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) * cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        of ObjectType.String:
            result = cast[ptr String](other).toStr().repeat(self.toInt()).asStr()
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '*' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc mul(self: ptr String, other: ptr Obj): ptr Obj =  # This can yield a float!
    case other.kind:
        of ObjectType.Integer:
            result = self.toStr().repeat(cast[ptr Integer](other).toInt()).asStr()
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '*' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc mul(self: ptr Float, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = (self.toFloat() * float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() * cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '*' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc mul*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self * other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).mul(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).mul(other)
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).mul(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).mul(other)
        of ObjectType.String:
            result = cast[ptr String](self).mul(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '*' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc trueDiv(self: ptr Infinity, other: ptr Obj): ptr Infinity =
    result = asInf()
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.isNegative = true
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '/' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc trueDiv(self: ptr NotANumber, other: ptr Obj): ptr NotANumber =
    result = asNan()
    case other.kind:
        of ObjectType.NotANumber, ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '/' for objects of type '{self.typeName()}' and '{other.typeName()}'")



proc trueDiv(self: ptr Integer, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = ((float self.toInt()) / (float cast[ptr Integer](other).toInt())).asFloat()  # so that 4 / 2 == 2.0
        of ObjectType.Float:
            let res = ((float self.toInt()) / cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '/' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc trueDiv(self: ptr Float, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = (self.toFloat() / float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() / cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '/' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc trueDiv*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self / other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).trueDiv(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).trueDiv(other)
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).trueDiv(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).trueDiv(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '/' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc pow(self: ptr Infinity, other: ptr Obj): ptr Infinity =
    result = asInf()
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.isNegative = true
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '**' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc pow(self: ptr NotANumber, other: ptr Obj): ptr NotANumber =
    result = asNan()
    case other.kind:
        of ObjectType.NotANumber, ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '**' for objects of type '{self.typeName()}' and '{other.typeName()}'")



proc pow(self: ptr Integer, other: ptr Obj): ptr Obj =  # This can yield a float!
    case other.kind:
        of ObjectType.Integer:
            result = (self.toInt() ** cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) ** cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '**' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc pow(self: ptr Float, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = (self.toFloat() ** float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() ** cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '**' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc pow*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ** other (exponentiation)
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).pow(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).pow(other)
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).pow(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).pow(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '**' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc divMod(self: ptr Infinity, other: ptr Obj): ptr Infinity =
    result = asInf()
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.isNegative = true
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '%' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc divMod(self: ptr NotANumber, other: ptr Obj): ptr NotANumber =
    result = asNan()
    case other.kind:
        of ObjectType.NotANumber, ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '%' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc divMod(self: ptr Integer, other: ptr Obj): ptr Obj =  # This can yield a float!
    case other.kind:
        of ObjectType.Integer:
            result = (self.toInt() mod cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) mod cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '%' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc divMod(self: ptr Float, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = (self.toFloat() mod float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() mod cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result = asInf()
            elif res == -system.Inf:
                let negInf = asInf()
                negInf.isNegative = true
                result = negInf
            else:
                result = res.asFloat()
        of ObjectType.NotANumber:
            result = asNan()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '%' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc divMod*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self % other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).divMod(other)
        of ObjectType.Float:
            result = cast[ptr Float](self).divMod(other)
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).divMod(other)
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).divMod(other)
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '%' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc binaryAnd(self, other: ptr Integer): ptr Integer =
    result = bitand(self.toInt(), other.toInt()).asInt()


proc binaryAnd*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self & other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryAnd(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '&' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc binaryOr(self, other: ptr Integer): ptr Integer =
    result = bitor(self.toInt(), other.toInt()).asInt()


proc binaryOr*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self | other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryOr(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '|' for objects of type '{self.typeName()}' and '{other.typeName()}'")


proc binaryNot(self: ptr Integer): ptr Integer =
    result = bitnot(self.toInt()).asInt()


proc binaryNot*(self: ptr Obj): ptr Obj =
    ## Returns the result of ~self
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryNot()
        else:
            raise newException(NotImplementedError, &"unsupported unary operator '~' for object of type '{self.typeName()}'")


proc binaryXor(self, other: ptr Integer): ptr Integer =
    result = bitxor(self.toInt(), other.toInt()).asInt()


proc binaryXor*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ^ other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryXor(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '^' for object of type '{self.typeName()}'")


proc binaryShr(self, other: ptr Integer): ptr Integer =
    result = (self.toInt() shr other.toInt()).asInt()


proc binaryShr*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self >> other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryShr(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '>>' for object of type '{self.typeName()}'")


proc binaryShl(self, other: ptr Integer): ptr Integer =
    result = (self.toInt() shr other.toInt()).asInt()


proc binaryShl*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self << other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryShl(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, &"unsupported binary operator '<<' for object of type '{self.typeName()}'")