# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Base structure for values and objects in JAPL, all
## types inherit from this simple structure

import tables

type
    Chunk* = ref object
        ## A piece of bytecode.
        ## Consts represents (TODO newdoc)
        ## Code represents (TODO newdoc)
        ## Lines represents (TODO newdoc)
        consts*: ValueArray
        code*: seq[uint8]
        lines*: seq[int]
        
    ValueType* {.pure.} = enum
      # All possible value types (this is the VM's notion of 'type', not the end user's)
      Integer, Double, Bool, Nil, Object, Nan, Inf, Minf
    Value* = object
        ## Represents an internal JAPL type
        case kind*: ValueType
            of ValueType.Integer:
                intValue*: int
            of ValueType.Double:
                floatValue*: float
            of ValueType.Bool:
                boolValue*: bool
            of ValueType.Nil, ValueType.Inf, ValueType.Nan, ValueType.Minf:
                discard
            of ValueType.Object:
                obj*: ptr Obj

    ObjectType* {.pure.} = enum
        ## The type of the object
        ## (Also see meta/valueobject/ValueType)
        String, Exception, Function,
        Class, Module
    Obj* = object of RootObj
        kind*: ObjectType
        hashValue*: uint32
    String* = object of Obj    # A string object
        str*: ptr UncheckedArray[char]  # TODO -> Unicode support
        len*: int
    Function* = object of Obj
        name*: ptr String
        arity*: int
        optionals*: int
        defaults*: Table[string, Value]
        chunk*: Chunk
    JAPLException* = object of Obj
        errName*: ptr String
        message*: ptr String





# Maps enum types to actual JAPL object types
const objectMapping = to_table({
                               String: Obj,  # TODO
                               Exception: Obj,
                               Function: Obj,
                               Class: Obj,
                               Module: Obj
                               })


template `convert`(a: ptr Obj): untyped =
    ## Performs conversions from a JAPL
    ## supertype to a subtype

    cast[ptr objectMapping[a.kind]](a)


proc objType*(obj: ptr Obj): ObjectType =
    ## Returns the type of the object
    return obj.kind


proc stringify*(obj: ptr Obj): string =
    ## Returns a string representation
    ## of the object
    result = "<object (built-in type)>"


proc typeName*(obj: ptr Obj): string =
    ## This method should return the
    ## name of the object type
    result = "object"


proc isFalsey*(obj: ptr Obj): bool =
    ## Returns wheter the object should
    ## be considered a falsey value
    ## or not. Returns true if the
    ## object IS falsey
    result = false


proc valuesEqual*(a: ptr Obj, b: ptr Obj): bool =
    ## Base method to compare 2 objects.
    ## Should never be used in normal
    ## circumstances, as it is not reliable.
    ## This is only a last option if an object
    ## hasn't this method defined
    result = a.kind == b.kind


proc hash*(self: ptr Obj): uint32 =
    # TODO: Make this actually useful
    result = 2166136261u32


proc add(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self + other
    ## or nil if the operation is unsupported
    result = nil  # Not defined for base objects!


proc sub(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self - other
    ## or nil if the operation is unsupported
    result = nil


proc mul(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self * other
    ## or nil if the operation is unsupported
    result = nil


proc trueDiv(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self / other
    ## or nil if the operation is unsupported
    result = nil


proc exp(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ** other
    ## or nil if the operation is unsupported
    result = nil


proc binaryAnd(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self & other
    ## or nil if the operation is unsupported
    result = nil


proc binaryOr(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self | other
    ## or nil if the operation is unsupported
    result = nil


proc binaryNot(self: ptr Obj): ptr Obj =
    ## Returns the result of ~self
    ## or nil if the operation is unsupported
    result = nil


proc binaryXor(self, other: ptr Obj): ptr Obj =
    ## Returns the result of self ^ other
    ## or nil if the operation is unsupported
    result = nil
