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


## Implementation for string objects

import baseObject
import numbers
import ../memory
import typeutils
import exception

import strutils
import strformat
import unicode


type
    String* = object of Obj
        ## A string object
        str*: ptr UncheckedArray[char]
        bytelen*: int
        len*: int


proc toStr*(obj: ptr Obj): string =
    ## Converts a JAPL string into a nim string
    var strObj = cast[ptr String](obj)
    for i in 0..strObj.bytelen:
        result.add(strObj.str[i])


proc hash*(self: ptr String): uint64 =
    ## Implements the FNV-1a hashing algorithm
    ## for strings
    result = 2166136261u
    for i in countup(0, self.len - 1):
        result = result xor uint64(self.str[i])
        result *= 16777619


proc asStr*(s: string): ptr String =
    ## Converts a nim string into a
    ## JAPL string
    result = allocateObj(String, ObjectType.String)
    result.str = allocate(UncheckedArray[char], char, s.len())
    for i in 0..<s.len:
        result.str[i] = s[i]
        result.bytelen += 1
    result.len = s.runeLen()
    if result.len > 0:
        result.hashValue = result.hash()
    else:
        result.hashValue = 0u


proc isFalsey*(self: ptr String): bool =
    result = self.len == 0


proc stringify*(self: ptr String): string =
    if self.len == 0:
        result = "''"
    else:
        result = self.toStr()


proc typeName*(self: ptr String): string =
    return "string"


proc eq*(self, other: ptr String): bool =
    if self.bytelen != other.bytelen:
        return false
    elif self.len != other.len:
        return false
    elif self.hash != other.hash:
        return false
    for i in 0..<self.bytelen:
        if self.str[i] != other.str[i]:
            return false
    result = true


proc sum*(self: ptr String, other: ptr Obj): returnType =
    result.kind = returnTypes.Object
    if other.isStr():
        var other = cast[ptr String](other)
        var selfStr = self.toStr()
        var otherStr = other.toStr()
        result.result = (selfStr & otherStr).asStr()
    else:
        raise newException(NotImplementedError, "")


proc mul*(self: ptr String, other: ptr Obj): returnType =
    result.kind = returnTypes.Object
    case other.kind:
        of ObjectType.Integer:
            result.result = self.toStr().repeat(cast[ptr Integer](other).toInt()).asStr()
        else:
            raise newException(NotImplementedError, "")


proc getItem*(self: ptr String, other: ptr Obj): returnType =
    result.kind = returnTypes.Object
    ## Handles getItem expressions
    var str = self.toStr()
    if not other.isInt():
        result.kind = returnTypes.Exception
        result.result = newTypeError("string indeces must be integers")
    else:
        var index: int = other.toInt()
        if index < 0:
            index = self.len + other.toInt()
            if index < 0:    # If even now it is less than 0 then it is out of bounds
                result.kind = returnTypes.Exception
                result.result = newIndexError("string index out of bounds")
        elif index >= self.len:
            result.kind = returnTypes.Exception
            result.result = newIndexError("string index out of bounds")
        else:
            var newStr = allocateObj(String, ObjectType.String)
            newStr.str = allocate(UncheckedArray[char], char, str.runeAt(index).toUTF8.runeLen())
            for i in countup(0, len(str.runeAt(index).toUTF8()) - 1):
                newStr.str[i] = self.str[i]
                newStr.bytelen += 1
            newStr.len = str.runeAt(index).toUTF8.runeLen()
            result.result = newStr


proc Slice*(self: ptr String, a: ptr Obj, b: ptr Obj): returnType =
    ## Handles slice expressions
    var startIndex = b.toInt()
    var endIndex = a.toInt()
    var a = a
    var b = b
    result.kind = returnTypes.Object
    if a.isNil():
        a = self.len.asInt()
    if b.isNil():
        b = 0.asInt()
    if not b.isInt() or not a.isInt():
        result.kind = returnTypes.Exception
        result.result = newTypeError("string indeces must be integers")
        return result
    elif startIndex < 0:
        startIndex = (self.len + startIndex)
        if startIndex < 0:
            startIndex = (self.len + endIndex)
    elif startIndex >= self.str.high():
        result.result = asStr("")
        return result
    if endIndex > self.str.high():
        endIndex = self.len
    if startIndex > endIndex:
        result.result = asStr("")
        return result
    var newStr = allocateObj(String, ObjectType.String)
    newStr.str = allocate(UncheckedArray[char], char, self.toStr().toRunes[startIndex..<endIndex].len())
    for i in countup(startIndex, endIndex - 1):
        newStr.str[i] = self.str[i]
        newStr.bytelen += 1
    newStr.len = newStr.toStr().runeLen()
    result.result = newStr
