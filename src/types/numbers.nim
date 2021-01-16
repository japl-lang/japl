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

# Implementation of numerical types

import baseObject
import typeutils

import bitops
import math

# Custom operators for exponentiation
proc `**`(a, b: int): int = pow(a.float, b.float).int
proc `**`(a, b: float): float = pow(a, b)


type
    Integer* = object of Obj
        ## An integer object
        intValue*: int  # TODO: Bignum arithmetic
    Float* = object of Integer
        ## A float object
        floatValue*: float
    Infinity* = object of Float   # Inf is considered a float
        ## An inf object
        isNegative*: bool  # This differentiates inf and -inf
    NotANumber* = object of Float     # NaN is a subclass of float (as per IEEE 754 spec)
        ## A nan object


proc toInt*(obj: ptr Obj): int =
    ## Converts a JAPL int to a nim int
    result = cast[ptr Integer](obj).intValue


proc toFloat*(obj: ptr Obj): float =
    ## Converts a JAPL float to a nim float
    result = cast[ptr Float](obj).floatValue


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


proc asNan*(): ptr NotANumber =
    ## Creates a nan object
    result = allocateObj(NotANumber, ObjectType.NotANumber)


proc asInf*(): ptr Infinity =
    ## Creates an inf object
    result = allocateObj(Infinity, ObjectType.Infinity)


proc typeName*(self: ptr NotANumber): string =
    result = "nan"


proc typeName*(self: ptr Infinity): string =
    result = "infinity"


proc typeName*(self: ptr Float): string =
    result = "float"


proc stringify*(self: ptr NotANumber): string =
    result = "nan"


proc hash*(self: ptr NotANumber): uint64 =
    # TODO: Hashable?
    raise newException(NotImplementedError, "unhashable type 'nan'")


proc eq*(self, other: ptr NotANumber): bool =
    result = false   # As per IEEE 754 spec, nan != nan


proc sum*(self: ptr NotANumber, other: ptr Obj): returnType =
    raise newException(NotImplementedError, "")


proc stringify*(self: ptr Infinity): string =
    if self.isNegative:
        result = "-inf"
    else:
        result = "inf"


proc isFalsey*(self: ptr Infinity): bool =
    result = false


proc hash*(self: ptr Infinity): uint64 =
    # TODO: Arbitrary hash seems a bad idea
    if self.isNegative:
        result = 1u
    else:
        result = 0u


proc negate*(self: ptr Infinity): returnType =
    result.result = nil
    if self.isNegative:
        result.kind = returnTypes.Inf
    else:
        result.kind = returnTypes.nInf


proc eq*(self, other: ptr Infinity): bool =
    result = self.isNegative == other.isNegative


proc lt*(self: ptr Infinity, other: ptr Obj): bool =
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
            raise newException(NotImplementedError, "")


proc gt*(self: ptr Infinity, other: ptr Obj): bool =
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
            raise newException(NotImplementedError, "")


proc sum*(self: ptr Infinity, other: ptr Obj): returnType =
    result.result = nil
    result.kind = returnTypes.Inf
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.kind = returnTypes.nInf
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, "")


proc sub*(self: ptr Infinity, other: ptr Obj): returnType =
    result.result = nil
    result.kind = returnTypes.Inf
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.kind = returnTypes.nInf
            elif not self.isNegative and not other.isNegative:
                result.kind = returnTypes.NotANumber
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, "")


proc stringify*(self: ptr Float): string =
    result = $self.floatValue


proc isFalsey*(self: ptr Float): bool =
    result = self.floatValue == 0.0


proc hash*(self: ptr Float): uint64 =
    result = 2166136261u xor uint64 self.floatValue   # TODO: Improve this
    result *= 16777619


proc eq*(self, other: ptr Float): bool =
    result = self.floatValue == other.floatValue


proc negate*(self: ptr Float): returnType =
    result.kind = returnTypes.Object
    result.result = (-self.toFloat()).asFloat()



proc typeName*(self: ptr Integer): string =
    result = "integer"


proc stringify*(self: ptr Integer): string =
    result = $self.intValue


proc isFalsey*(self: ptr Integer): bool =
    result = self.intValue == 0


proc eq*(self, other: ptr Integer): bool =
    result = self.intValue == other.intValue


proc negate*(self: ptr Integer): returnType =
    result.kind = returnTypes.Object
    result.result = (-self.toInt()).asInt()


proc hash*(self: ptr Integer): uint64 = 
    result = uint64 self.intValue


proc lt*(self: ptr Integer, other: ptr Obj): bool =
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
            raise newException(NotImplementedError, "")


proc lt*(self: ptr Float, other: ptr Obj): bool =
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
            raise newException(NotImplementedError, "")


proc gt*(self: ptr Integer, other: ptr Obj): bool =
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
            raise newException(NotImplementedError, "")


proc gt*(self: ptr Float, other: ptr Obj): bool =
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
            raise newException(NotImplementedError, "")


proc sum*(self: ptr Integer, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toInt() + cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) + cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.Inf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc sum*(self: ptr Float, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toFloat() + float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() + cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.Inf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc sub*(self: ptr Integer, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toInt() - cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) - cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc sub*(self: ptr NotANumber, other: ptr Obj): returnType =
    raise newException(NotImplementedError, "")


proc sub*(self: ptr Float, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toFloat() - float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() - cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc mul*(self: ptr Infinity, other: ptr Obj): returnType =
    result.result = nil
    result.kind = returnTypes.Inf
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.kind = returnTypes.nInf
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, "")


proc mul*(self: ptr NotANumber, other: ptr Obj): returnType =
    raise newException(NotImplementedError, "")



proc mul*(self: ptr Integer, other: ptr Obj): returnType = 
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toInt() * cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) * cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")



proc mul*(self: ptr Float, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toFloat() * float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() * cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc trueDiv*(self: ptr Infinity, other: ptr Obj): returnType =
    result.result = nil
    result.kind = returnTypes.Inf
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.kind = returnTypes.nInf
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, "")


proc trueDiv*(self: ptr NotANumber, other: ptr Obj): returnType =
    raise newException(NotImplementedError, "")



proc trueDiv*(self: ptr Integer, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (float(self.toInt()) / float(cast[ptr Integer](other).toInt())).asFloat()  # So that 4 / 2 == 2.0
        of ObjectType.Float:
            let res = ((float self.toInt()) / cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc trueDiv*(self: ptr Float, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toFloat() / float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() / cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc pow*(self: ptr Infinity, other: ptr Obj): returnType =
    result.result = nil
    result.kind = returnTypes.Inf
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.kind = returnTypes.nInf
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, "")


proc pow*(self: ptr NotANumber, other: ptr Obj): returnType =
    raise newException(NotImplementedError, "")



proc pow*(self: ptr Integer, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toInt() ** cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) ** cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")



proc pow*(self: ptr Float, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toFloat() ** float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() ** cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")



proc divMod*(self: ptr Infinity, other: ptr Obj): returnType =
    result.result = nil
    result.kind = returnTypes.Inf
    case other.kind:
        of ObjectType.Infinity:
            var other = cast[ptr Infinity](other)
            if self.isNegative or other.isNegative:
                result.kind = returnTypes.nInf
        of ObjectType.Integer, ObjectType.Float:
            discard
        else:
            raise newException(NotImplementedError, "")


proc divMod*(self: ptr NotANumber, other: ptr Obj): returnType =
    raise newException(NotImplementedError, "")


proc divMod*(self: ptr Integer, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toInt() mod cast[ptr Integer](other).toInt()).asInt()
        of ObjectType.Float:
            let res = ((float self.toInt()) mod cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc divMod*(self: ptr Float, other: ptr Obj): returnType =
    case other.kind:
        of ObjectType.Integer:
            result.kind = returnTypes.Object
            result.result = (self.toFloat() mod float cast[ptr Integer](other).toInt()).asFloat()
        of ObjectType.Float:
            let res = (self.toFloat() mod cast[ptr Float](other).toFloat())
            if res == system.Inf:
                result.kind = returnTypes.Inf
                result.result = nil
            elif res == -system.Inf:
                result.kind = returnTypes.nInf
                result.result = nil
            else:
                result.kind = returnTypes.Object
                result.result = res.asFloat()
        of ObjectType.Infinity:
            result.kind = returnTypes.nInf
            result.result = nil
        else:
            raise newException(NotImplementedError, "")


proc binaryAnd*(self, other: ptr Integer): returnType =
    result.kind = returnTypes.Object
    result.result = bitand(self.toInt(), other.toInt()).asInt()


proc binaryOr*(self, other: ptr Integer): returnType =
    result.kind = returnTypes.Object
    result.result = bitor(self.toInt(), other.toInt()).asInt()


proc binaryNot*(self: ptr Integer): returnType =
    result.kind = returnTypes.Object
    result.result = bitnot(self.toInt()).asInt()


proc binaryXor*(self, other: ptr Integer): returnType =
    result.kind = returnTypes.Object
    result.result = bitxor(self.toInt(), other.toInt()).asInt()



proc binaryShr*(self, other: ptr Integer): returnType =
    result.kind = returnTypes.Object
    result.result = (self.toInt() shr other.toInt()).asInt()



proc binaryShl*(self, other: ptr Integer): returnType =
    result.kind = returnTypes.Object
    result.result = (self.toInt() shr other.toInt()).asInt()
