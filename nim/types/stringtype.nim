# This module implements the interface for strings in JAPL.
# Strings are manually-allocated arrays of characters, and are
# therefore immutable from the user's perspective. They are
# natively ASCII encoded, but soon they will support for unicode.

import objecttype
import ../memory


type String* = ref object of Obj
    str*: ptr UncheckedArray[char]  #TODO -> Maybe ptr UncheckedArray[array[4, char]]?
    len*: int


method stringify*(s: String): string =
    result = $s.str


method isFalsey*(s: String): bool =
    result = s.len == 0

method valuesEqual*(a: String, b: String): bool =
    if a.len != b.len:
        return false
    for i in 0..a.len - 1:
        if a.str[i] != b.str[i]:
            return false
    return true


proc newString*(str: string): String =
    # TODO -> Unicode
    result = String()
    var arrStr = cast[ptr UncheckedArray[char]](reallocate(nil, 0, sizeof(char) * len(str)))
    var length = len(str)
    for i in 0..len(str) - 1:
        arrStr[i] = str[i]
    result.str = arrStr
    result.len = length


proc typeName*(s: String): string =
    return "string"
