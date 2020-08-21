# Implementation for function objects in JAPL.
# In JAPL, functions (like any other entity) are First Class Objects.
# Each function owns its chunk object, which makes the implementation
# easier and opens up for interesting features in the future, like
# code objects that can be compiled inside the JAPL runtime, pretty much
# like in Python


import objecttype
import stringtype
import ../meta/chunk
import strformat


type Function* = ref object of Obj
    name*: String
    arity*: int
    chunk*: Chunk


func newFunction*(name: string = "", chunk: Chunk = initChunk(), arity: int = 0): Function =
    result = Function(name, arity, chunk)


method isFalsey*(fn: Function): bool =
    return false


method stringify*(fn: Function): string =
    result = &"<function object '{stringify(fn.name)}' (built-in type)>"


method valuesEqual*(a, b: Function): bool =
    result = a.name == b.name
