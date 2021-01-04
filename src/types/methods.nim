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


## Implementations for dispatcher methods of JAPL objects.
## This modules serves to avoid recursive dependencies

import baseObject
import japlString
import function
import boolean
import japlNil
import numbers
import native


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
        of ObjectType.Native:
            result = cast[ptr Native](self).typeName()
        else:
            discard


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
        of ObjectType.Native:
            result = cast[ptr Native](self).stringify()
        else:
            discard


proc hash*(self: ptr Obj): uint64 =
    ## Returns the hash of the object using
    ## the FNV-1a algorithm (or a predefined value).
    ## Raises an error if the object is not hashable
    if not self.isHashable:
        raise newException(NotImplementedError, "")
    case self.kind:
        of ObjectType.BaseObject:
            result = 2166136261u  # Constant hash
        of ObjectType.String:
            result = cast[ptr String](self).hash()
        of ObjectType.Integer:
            result = uint64 cast[ptr Integer](self).hash()
        of ObjectType.Float:
            result = cast[ptr Float](self).hash()
        of ObjectType.Bool:
            let b = cast[ptr Bool](self)
            if b.boolValue:
                result = uint64 1
            else:
                result = uint64 0
        of ObjectType.Function:
            result = cast[ptr Function](self).hash()
        of ObjectType.Infinity:
            result = cast[ptr Infinity](self).hash()
        of ObjectType.NotANumber:
            result = cast[ptr NotANumber](self).hash()
        of ObjectType.Nil:
            result = cast[ptr Nil](self).hash()
        of ObjectType.Native:
            result = cast[ptr Native](self).hash()
        else:
            discard


proc isFalsey*(self: ptr Obj): bool =
    ## Returns true if the object is
    ## falsey, false otherwise
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
        of ObjectType.Native:
            result = cast[ptr Native](self).isFalsey()
        else:
            discard


proc eq*(self, other: ptr Obj): bool =
    ## Compares two objects for equality,
    ## returns true if self equals other
    ## and false otherwise
    if self.kind != other.kind:   # If the types are different it's not
    # even worth going any further (and we couldn't anyway)
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
        of ObjectType.Native:
            var self = cast[ptr Native](self)
            var other = cast[ptr Native](other)
            result = self.eq(other)
        else:
            discard


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
            raise newException(NotImplementedError, "")


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
            raise newException(NotImplementedError, "")


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
            raise newException(NotImplementedError, "")


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
            raise newException(NotImplementedError, "")


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
            raise newException(NotImplementedError, "")


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
            raise newException(NotImplementedError, "")


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
            raise newException(NotImplementedError, "")


proc binaryAnd*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self & other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryAnd(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, "")



proc binaryOr*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self | other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryOr(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, "")


proc binaryXor*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ^ other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryXor(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, "")


proc binaryShr*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self >> other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryShr(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, "")


proc binaryShl*(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self << other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryShl(cast[ptr Integer](other))
        else:
            raise newException(NotImplementedError, "")


proc binaryNot*(self: ptr Obj): ptr Obj =
    ## Returns the result of self ~other
    ## or raises NotImplementedError if the operation is unsupported
    case self.kind:
        of ObjectType.Integer:
            result = cast[ptr Integer](self).binaryNot()
        else:
            raise newException(NotImplementedError, "")


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
            raise newException(NotImplementedError, "")


proc gt*(self: ptr Obj, other: ptr Obj): bool = 
    ## Returns the result of self > other or
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
            raise newException(NotImplementedError, "")



## Utilities to inspect JAPL objects


proc objType*(obj: ptr Obj): ObjectType =
    ## Returns the type of the object
    result = obj.kind


proc isCallable*(obj: ptr Obj): bool =
    ## Returns true if the given object
    ## is callable, false otherwise
    result = obj.kind in {ObjectType.Function, ObjectType.Class, ObjectType.Native}


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
    ## either a JAPL number, infinity or nan.
    ## Note to JavaScript developers: No, in JAPL
    ## nan is not a number. Here we consider it like
    ## a number because internally it's easier to
    ## represent it like that for methods that perform
    ## binary operations on numbers, since 2 * nan is 
    ## valid JAPL code and will yield nan
    result = isInt(obj) or isFloat(obj) or isInf(obj) or isNan(obj)


proc isStr*(obj: ptr Obj): bool =
    ## Returns true if the given object is a JAPL string
    result = obj.kind == ObjectType.String
