# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at

#  http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Implementation for function objects in JAPL.
# In JAPL, functions (like any other entity) are First Class Objects.
# Each function owns its chunk object, which makes the implementation
# easier and opens up for interesting features in the future, like
# code objects that can be compiled inside the JAPL runtime, pretty much
# like in Python

import objecttype
import stringtype
import strformat
import ../memory
import ../meta/chunk
import ../meta/valueobject
import tables


type
    Function* = object of Obj
        name*: ptr String
        arity*: int
        optionals*: int
        defaults*: Table[string, Value]
        chunk*: Chunk
    FunctionType* = enum
        FUNC, SCRIPT


proc newFunction*(name: string = "", chunk: Chunk = newChunk(), arity: int = 0): ptr Function =
    result = allocateObj(Function, ObjectType.Function)
    if name.len > 1:
        result.name = newString(name)
    else:
        result.name = nil
    result.arity = arity
    result.chunk = chunk


proc isFalsey*(fn: Function): bool =
    return false


proc stringify*(fn: ptr Function): string =
    if fn.name != nil:
        result = &"<function '{stringify(fn.name)}'>"
    else:
        result = &"<code object>"


proc valuesEqual*(a, b: ptr Function): bool =
    result = a.name.stringify == b.name.stringify


proc typeName*(self: ptr Function): string =
    result = "function"
