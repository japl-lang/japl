# This module implements the interface for strings in JAPL.
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
    result = ""


method isFalsey*(s: String): bool =
    result = s.len == 0


method valuesEqual*(a: String, b: String): bool =
    if a.kind != b.kind:
        result = false
    else:
        result = a.str == b.str


proc newString*(str: string): String =
    var strObj = allocateObj(String, ObjectTypes.STRING)
    strObj.str = cast[ptr UncheckedArray[char]](reallocate(nil, 0, sizeof(char) * len(str)))
    strObj.len = len(str)
    for i in 0..len(str) - 1:
        strObj.str[i] = str[i]
