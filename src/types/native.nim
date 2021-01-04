import baseObject
import ../meta/opcode
import japlString


type
    Native* = object of Obj
        ## A native object
        name*: ptr String
        arity*: int    # The number of required parameters
        optionals*: int   # The number of optional parameters
        defaults*: seq[ptr Obj]   # List of default arguments, in order
        nimproc*: proc (args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj]   # The function's body


proc newNative*(name: string, nimproc: proc(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj], arity: int = 0): ptr Native =
    ## Allocates a new native object with the given
    ## bytecode chunk and arity. If the name is an empty string
    ## (the default), the function will be an
    ## anonymous code object
    result = allocateObj(Native, ObjectType.Native)
    if name.len > 1:
        result.name = name.asStr()
    else:
        result.name = nil
    result.arity = arity
    result.nimproc = nimproc
    result.isHashable = false


proc typeName*(self: ptr Native): string =
    result = "function"


proc stringify*(self: ptr Native): string =
    if self.name != nil:
        result = "<function '" & self.name.toStr() & "'>"
    else:
        result = "<code object>"


proc isFalsey*(self: ptr Native): bool =
    result = false


proc hash*(self: ptr Native): uint64 =
    # TODO: Hashable?
    raise newException(NotImplementedError, "unhashable type 'native'")


proc eq*(self, other: ptr Native): bool =
    result = self.name.stringify() == other.name.stringify()
