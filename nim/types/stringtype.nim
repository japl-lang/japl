# This module implements the interface for strings in JAPL.ob
# Strings are natively utf-8 encoded, and for now we are using
# Nim's own garbage collected string type to represent them. In
# the future, when a proper custom GC is in place, the implementation
# will shift towards an array of characters
import objecttype
import ../memory


type String* = ref object of Obj
    str*: ptr UncheckedArray[char]
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
    result = String()
    var arrStr = cast[ptr UncheckedArray[char]](reallocate(nil, 0, sizeof(char) * len(str)))
    var length = len(str)
    for i in 0..len(str) - 1:
        arrStr[i] = str[i]
    result.str = arrStr
    result.len = length


proc typeName*(s: String): string =
    return "string"
