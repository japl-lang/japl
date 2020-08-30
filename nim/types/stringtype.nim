# This module implements the interface for strings in JAPL.
# Strings are manually-allocated arrays of characters, and are
# therefore immutable from the user's perspective. They are
# natively ASCII encoded, but soon they will support for unicode.

import objecttype
import ../memory


type String* = object of Obj
    str*: ptr UncheckedArray[char]  #TODO -> Maybe ptr UncheckedArray[array[4, char]]?
    len*: int


proc stringify*(s: String): string =
    $s.str


proc isFalsey*(s: String): bool =
    result = s.len == 0


proc hash*(self: String): uint32 =
    result = 2166136261u32
    var i = 0
    while i < self.len:
        result = result xor uint32 self.str[i]
        result *= 16777619
        i += 1
    return result


proc valuesEqual*(a: String, b: String): bool =
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
    result = allocateObj(String, ObjectTypes.STRING)
    result.str = allocate(UncheckedArray[char], char, len(str))
    for i in 0..len(str) - 1:
        result.str[i] = str[i]
    result.len = len(str)
    result.hashValue = result[].hash()


proc typeName*(s: String): string =
    return "string"