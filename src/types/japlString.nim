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
import strutils


type
    String* = object of Obj
        ## A string object
        str*: ptr UncheckedArray[char]  # TODO -> Unicode support
        len*: int


proc toStr*(obj: ptr Obj): string =
    ## Converts a JAPL string into a nim string
    var strObj = cast[ptr String](obj)
    for i in 0..strObj.str.len - 1:
        result.add(strObj.str[i])


proc hash*(self: ptr String): uint64 =
    result = 2166136261u
    var i = 0
    while i < self.len:
        result = result xor uint64 self.str[i]
        result *= 16777619
        i += 1
    return result


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


proc isFalsey*(self: ptr String): bool =
    result = self.len == 0


proc stringify*(self: ptr String): string =
    result = self.toStr()


proc typeName*(self: ptr String): string =
    return "string"


proc eq*(self, other: ptr String): bool =
    if self.len != other.len:
        return false
    elif self.hash != other.hash:
        return false
    for i in 0..self.len - 1:
        if self.str[i] != other.str[i]:
            return false
    result = true


proc sum*(self: ptr String, other: ptr Obj): ptr String =
    if other.kind == ObjectType.String:
        var other = cast[ptr String](other)
        var selfStr = self.toStr()
        var otherStr = other.toStr()
        result = (selfStr & otherStr).asStr()
    else:
        raise newException(NotImplementedError, "")


proc mul*(self: ptr String, other: ptr Obj): ptr Obj =
    case other.kind:
        of ObjectType.Integer:
            result = self.toStr().repeat(cast[ptr Integer](other).toInt()).asStr()
        else:
            raise newException(NotImplementedError, "")
