# All entities in JAPL are objects. Currently, this module serves more
# as a logical root rather than an actual implementation, but it will
# be needed in the future when more and more default methods are added
# to objects, without having to add a (possibly redundant) implementation
# into each specific file in the types directory


type
    ObjectTypes* = enum
        STRING, EXCEPTION, FUNCTION,
        CLASS, MODULE
    Obj* = ref object of RootObj
        kind*: ObjectTypes


func objType*(obj: Obj): ObjectTypes =
    return obj.kind


method stringify*(obj: Obj): string {.base.} =
    result = "<object (built-in type)>"


method typeName*(obj: Obj): string {.base.} =
    result = "object"


method isFalsey*(obj: Obj): bool {.base.} =
    result = false


method valuesEqual*(a: Obj, b: Obj): bool {.base.} =
    result = a.kind == b.kind
