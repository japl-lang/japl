# All entities in JAPL are objects. Currently, this module serves more
# as a logical root rather than an actual implementation, but it will
# be needed in the future when more and more default methods are added
# to objects, without having to add a (possibly redundant) implementation
# into each specific file in the types directory


type
    ObjectTypes* = enum
        STRING, EXCEPTION, FUNCTION,
        CLASS, MODULE
    Obj* = object of RootObj
        kind*: ObjectTypes
        hashValue*: uint32
        next*: ptr Obj


func objType*(obj: Obj): ObjectTypes =
    return obj.kind


proc stringify*(obj: Obj): string   =
    result = "<object (built-in type)>"


proc typeName*(obj: Obj): string   =
    result = "object"


proc isFalsey*(obj: Obj): bool   =
    result = false


proc valuesEqual*(a: Obj, b: Obj): bool   =
    result = a.kind == b.kind


proc hash*(self: Obj): uint32 =
    result = 2166136261u32
    # Add more
