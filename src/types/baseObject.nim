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


import ../memory


type
    NotImplementedError* = object of CatchableError
        ## Raised when a given operation is unsupported
        ## on a given type
    ObjectType* {.pure.} = enum
        ## All the possible object types
        String, Exception, Function,
        Class, Module, BaseObject,
        Integer, Float, Bool, NotANumber,
        Infinity, Nil
    Obj* = object of RootObj
        ## The base object for all
        ## JAPL types. Every object
        ## in JAPL implicitly inherits
        ## from this base type
        kind*: ObjectType
        hashValue*: uint64
        isHashable*: bool   # This is false for unhashable objects


## Object constructors and allocators

proc allocateObject*(size: int, kind: ObjectType): ptr Obj =
    ## Wrapper around memory.reallocate to create a new generic JAPL object
    result = cast[ptr Obj](reallocate(nil, 0, size))
    result.kind = kind


template allocateObj*(kind: untyped, objType: ObjectType): untyped =
    ## Wrapper around allocateObject to cast a generic object
    ## to a more specific type
    cast[ptr kind](allocateObject(sizeof kind, objType))


proc newObj*(): ptr Obj =
    ## Allocates a generic JAPL object
    result = allocateObj(Obj, ObjectType.BaseObject)


proc asObj*(self: ptr Obj): ptr Obj = 
    ## Casts a specific JAPL object into a generic
    ## pointer to Obj
    
    result = cast[ptr Obj](self)
