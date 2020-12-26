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
import japlString


type
    JAPLException* = object of Obj    # TODO: Create exceptions subclasses
        ## The base exception object
        errName*: ptr String    # TODO: Ditch error name in favor of inheritance-based types
        message*: ptr String



proc newIndexError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "IndexError".asStr()
    result.message = message.asStr()


proc newReferenceError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "ReferenceError".asStr()
    result.message = message.asStr()


proc newInterruptedError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "InterruptedError".asStr()
    result.message = message.asStr()


proc newRecursionError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "RecursionError".asStr()
    result.message = message.asStr()


proc newTypeError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = "TypeError".asStr()
    result.message = message.asStr()


proc stringify*(self: ptr JAPLException): string =
    result = self.errName.toStr() & ": " & self.message.toStr()

