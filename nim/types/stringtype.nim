# This module implements the interface for strings in JAPL.
# Strings are natively utf-8 encoded, and for now we are using
# Nim's own garbage collected string type to represent them. In
# the future, when a proper custom GC is in place, the implementation
# will shift towards an array of characters
import objecttype
import strutils


type String* = ref object of Obj
    str*: string


method stringify*(s: String): string =
    result = strutils.escape(s.str)


method isFalsey*(s: String): bool =
    result = len(s.str) == 0


method valuesEqual*(a: String, b: String): bool =
    if a.kind != b.kind:
        result = false
    else:
        result = a.str == b.str


func newString*(str: string): String =
    result = String(kind: STRING, str: str)

