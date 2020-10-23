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


## Defines JAPL exceptions

import stringtype
import japlvalue
import strformat
import ../memory


proc stringify*(self: ptr JAPLException): string =
    return &"{self.errName.stringify}: {self.message.stringify}"

proc isFalsey*(self: ptr JAPLException): bool =
    return false

proc newTypeError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("TypeError")
    result.message = newString(message)


proc newIndexError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("IndexError")
    result.message = newString(message)


proc newReferenceError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("ReferenceError")
    result.message = newString(message)


proc newInterruptedError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("InterruptedError")
    result.message = newString(message)


proc newRecursionError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectType.Exception)
    result.errName = newString("RecursionError")
    result.message = newString(message)

