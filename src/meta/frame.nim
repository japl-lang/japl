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

## Implementation of JAPL call frames. A call frame
## is a subset of the VM's stack that represent
## functions' local space

import ../types/jobject     


type
    CallFrame* = ref object    # FIXME: Call frames are broken (end indexes are likely wrong)
        function*: ptr Function
        ip*: int
        slot*: int
        endSlot*: int
        stack*: seq[ptr Obj]
        

proc getView*(self: CallFrame): seq[ptr Obj] =
    result = self.stack[self.slot..self.endSlot - 1]


proc getAbsIndex(self: CallFrame, idx: int): int =
    return idx + len(self.getView()) - 1   # TODO: Inspect this code (locals, functions)


proc len*(self: CallFrame): int =
    result = len(self.getView())


proc `[]`*(self: CallFrame, idx: int): ptr Obj =
    result = self.stack[self.getAbsIndex(idx)]


proc `[]=`*(self: CallFrame, idx: int, val: ptr Obj) =
    if idx < self.slot:
        raise newException(IndexError, "CallFrame index out of range")
    self.stack[self.getAbsIndex(idx)] = val


proc delete*(self: CallFrame, idx: int) =
    if idx < self.slot or idx > self.endSlot:
        raise newException(IndexError, "CallFrame index out of range")
    self.stack.delete(idx)
