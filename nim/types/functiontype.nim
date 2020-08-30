# Implementation for function objects in JAPL.
# In JAPL, functions (like any other entity) are First Class Objects.
# Each function owns its chunk object, which makes the implementation
# easier and opens up for interesting features in the future, like
# code objects that can be compiled inside the JAPL runtime, pretty much
# like in Python

import objecttype
import stringtype
import strformat
import ../memory
import ../meta/chunk


type
    Function* = object of Obj
        name*: ptr String
        arity*: int
        optionals*: int
        defaults*: seq[string]
        chunk*: Chunk
    FunctionType* = enum
        FUNC, SCRIPT


proc newFunction*(name: string = "", chunk: Chunk = initChunk(), arity: int = 0): ptr Function =
    result = allocateObj(Function, ObjectTypes.FUNCTION)
    result.name = newString(name)
    result.arity = arity
    result.chunk = chunk


proc isFalsey*(fn: Function): bool =
    return false


proc stringify*(fn: Function): string =
    result = &"<function object '{stringify(fn.name[])}' (built-in type)>"


proc valuesEqual*(a, b: Function): bool =
    result = a.name == b.name