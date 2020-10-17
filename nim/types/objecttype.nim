## All entities in JAPL are objects. Currently, this module serves more
## as a logical root rather than an actual implementation, but it will
## be needed in the future when more and more default methods are added
## to objects, without having to add a (possibly redundant) implementation
## into each specific file in the types directory


type
  ObjectType* {.pure.} = enum
    ## The type of the object 
    ## (Also see meta/valueobject/ValueType)
    String, Exception, Function,
    Class, Module
  Obj* = object of RootObj
    kind*: ObjectType
    hashValue*: uint32


func objType*(obj: ptr Obj): ObjectType =
  return obj.kind


proc stringify*(obj: ptr Obj): string =
  result = "<object (built-in type)>"


proc typeName*(obj: ptr Obj): string =
  result = "object"


proc isFalsey*(obj: ptr Obj): bool =
  result = false


proc valuesEqual*(a: ptr Obj, b: ptr Obj): bool =
  # probably a TODO, correct me if I'm wrong
  result = a.kind == b.kind


proc hash*(self: ptr Obj): uint32 =
  # probably a TODO, correct me if I'm wrong
  result = 2166136261u32
