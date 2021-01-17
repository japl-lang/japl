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

# Implementation for a simple FFI between JAPL and nim

import baseObject
import japlString


type retNative* {.pure.} = enum
    ## Defines all the possible native
    ## return types (this is useful
    ## to keep singletons actually
    ## singletons and makes it easier
    ## to bring back exceptions as well)
    False,
    True,
    Inf,
    nInf,
    Nil,
    NotANumber,
    Object,
    Exception


type
    Native* = object of Obj
        ## A native object
        name*: ptr String
        arity*: int    # The number of required parameters
        optionals*: int   # The number of optional parameters (TODO)
        defaults*: seq[ptr Obj]   # List of default arguments, in order (TODO)
        nimproc*: proc (args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj]   # The function's body


proc newNative*(name: string, nimproc: proc(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj], arity: int = 0): ptr Native =
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


proc typeName*(self: ptr Native): string =
    result = "function"


proc stringify*(self: ptr Native): string =
    if self.name != nil:
        result = "<built-in function '" & self.name.toStr() & "'>"
    else:
        result = "<code object>"


proc isFalsey*(self: ptr Native): bool =
    result = false


proc hash*(self: ptr Native): uint64 =
    # TODO: Hashable?
    raise newException(NotImplementedError, "unhashable type 'function'")


proc eq*(self, other: ptr Native): bool =
    result = self.name.stringify() == other.name.stringify()
