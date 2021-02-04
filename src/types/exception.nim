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

# Implementation of JAPL exceptions (WIP)

import baseObject

import strformat


type
    JAPLException* = object of Obj    # TODO: Create exceptions subclasses
        ## The base exception object
        # TODO -> Use ptr String again once
        # the recursive dependency is fixed
        errName*: string    # TODO: Ditch error name in favor of inheritance-based builtin types
        message*: string



proc newIndexError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "IndexError"
    result.message = message


proc newReferenceError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "ReferenceError"
    result.message = message


proc newInterruptedError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "InterruptedError"
    result.message = message


proc newRecursionError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "RecursionError"
    result.message = message


proc newTypeError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "TypeError"
    result.message = message


proc newValueError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "ValueError"
    result.message = message


proc stringify*(self: ptr JAPLException): string =
    result = &"{self.errName}: {self.message}"
