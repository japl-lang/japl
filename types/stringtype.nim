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

# This module implements the interface for strings in JAPL.
# Strings are manually-allocated arrays of characters, and are
# therefore immutable from the user's perspective. They are
# natively ASCII encoded, but soon they will support for unicode.

import japlvalue
import strformat
import ../memory


proc stringify*(s: ptr String): string =
    result = ""
    for i in 0..<s.len:
        result = result & (&"{s.str[i]}")


proc isFalsey*(s: ptr String): bool =
    result = s.len == 0


proc hash*(self: ptr String): uint32 =
    result = 2166136261u32
    var i = 0
    while i < self.len:
        result = result xor uint32 self.str[i]
        result *= 16777619
        i += 1
    return result


proc eq*(a: ptr String, b: ptr String): bool =
    if a.len != b.len:
        return false
    elif a.hash != b.hash:
        return false
    for i in 0..a.len - 1:
        if a.str[i] != b.str[i]:
            return false
    return true


proc newString*(str: string): ptr String =
    # TODO -> Unicode
    result = allocateObj(String, ObjectType.String)
    result.str = allocate(UncheckedArray[char], char, len(str))
    for i in 0..len(str) - 1:
        result.str[i] = str[i]
    result.len = len(str)
    result.hashValue = result.hash()


proc typeName*(s: ptr String): string =
    return "string"


proc asStr*(s: string): Value =
    ## Creates a string object
    result = Value(kind: ValueType.Object, obj: newString(s))
