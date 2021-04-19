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

## Implements closures

import baseObject
import function
import ../memory


type Closure* = object of Obj
    ## Represents a function
    ## closing over values outside
    ## of its lexical scope
    function*: ptr Function


proc newClosure(function: ptr Function): ptr Closure =
    ## Initializes a new closure from a function
    ## object
    result = allocateObject(Closure, ObjectType.Closure)
    result.function = function


proc typeName*(self: ptr Closure): string =
    result = "function"


proc stringify*(self: ptr Closure): string =
    if self.function.name != nil:
        if self.function.name.toStr() == "<lambda function>":
            result = self.function.name.toStr()
        else:
            result = "<function '" & self.function.name.toStr() & "'>"
    else:
        result = "<code object>"


proc isFalsey*(self: ptr Closure): bool =
    result = false


proc hash*(self: ptr Closure): uint64 =
    result = uint64(393027534)   # Arbitrary hash because ¯\_(ツ)_/¯


proc eq*(self, other: ptr Closure): bool =
    result = self.function == other.function  # Pointer equality


proc eq*(self: ptr Closure, other: ptr Function): bool =
    result = self.function == other
