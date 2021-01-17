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

import baseObject
import numbers


type
    Bool* = object of Integer
        ## A boolean object
        boolValue*: bool  # If the boolean is true or false


proc asBool*(b: bool): ptr Bool =
    ## Converts a nim bool into a JAPL bool
    result = allocateObj(Bool, ObjectType.Bool)
    result.boolValue = b


proc typeName*(self: ptr Bool): string = 
    result = "boolean"


proc stringify*(self: ptr Bool): string =
    result = $self.boolValue


proc isFalsey*(self: ptr Bool): bool =
    result = not self.boolValue


proc eq*(self, other: ptr Bool): bool =
    result = self.boolValue == other.boolValue


proc toBool*(obj: ptr Obj): bool =
    ## Converts a JAPL bool to a nim bool
    result = cast[ptr Bool](obj).boolValue

