import strutils
import strformat

type
    ObjectTypes* = enum
        STRING, EXCEPTION
    Obj* = ref object of RootObj
        case kind*: ObjectTypes
            of STRING:
                str*: string
            of EXCEPTION:
                errName*: Obj
                message*: Obj


proc isFalsey*(obj: Obj): bool =
    case obj.kind:
        of STRING:
            return len(obj.str) > 0
        else:
            return false


proc objType*(obj: Obj): ObjectTypes =
    return obj.kind


proc stringify*(obj: Obj): string =
    case obj.kind:
        of STRING:
            return strutils.escape(obj.str)
        of ObjectTypes.EXCEPTION:
            return &"{obj.errName.str}: {obj.message.str}"


proc valuesEqual*(a: Obj, b: Obj): bool =
    if a.kind != b.kind:
        return false
    case a.kind:
        of STRING:
            return a.str == b.str
        of EXCEPTION:
            return a.errName == b.errName and a.message == b.message
