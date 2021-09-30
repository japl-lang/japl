import baseObject
import ../meta/opcode
import japlString
import arrayList


type
    FunctionType* {.pure.} = enum
        ## All code in JAPL is compiled
        ## as if it was inside some sort
        ## of function. To differentiate
        ## between actual functions and
        ## the top-level code, this tiny
        ## enum is used to tell the two
        ## contexts apart when compiling
        Func, Script, Lambda

    Function* = object of Obj
        ## A function object
        name*: ptr String
        arity*: int    # The number of required parameters
        optionals*: int   # The number of optional parameters
        defaults*: ptr ArrayList[ptr String]
        chunk*: Chunk   # The function's body


proc newFunction*(name: string = "", chunk: Chunk, arity: int = 0): ptr Function =
    ## Allocates a new function object with the given
    ## bytecode chunk and arity. If the name is an empty string
    ## (the default), the function will be an
    ## anonymous code object
    # TODO: Add support for optional parameters
    result = allocateObj(Function, ObjectType.Function)
    if name.len >= 1:
        result.name = name.asStr()
    else:
        result.name = nil
    result.arity = arity
    result.chunk = chunk
    result.optionals = 0  # TODO
    result.defaults = newArrayList[ptr String]()


proc newLambda*(chunk: Chunk, arity: int = 0): ptr Function =
    ## Allocates a new lambda object (anonymous function) with the given
    ## bytecode chunk and arity
    # TODO: Add support for optional parameters
    result = allocateObj(Function, ObjectType.Function)
    result.name = "<lambda function>".asStr()
    result.arity = arity
    result.chunk = chunk
    result.optionals = 0


proc typeName*(self: ptr Function): string =
    result = "function"


proc stringify*(self: ptr Function): string =
    if self.name != nil:
        if self.name.toStr() == "<lambda function>":
            result = self.name.toStr()
        else:
            result = "<function '" & self.name.toStr() & "'>"
    else:
        result = "<code object>"


proc isFalsey*(self: ptr Function): bool =
    result = false


proc hash*(self: ptr Function): uint64 =
    # TODO: Hashable?
    raise newException(NotImplementedError, "unhashable type 'function'")


proc eq*(self, other: ptr Function): bool =
    result = self == other  # Pointer equality
