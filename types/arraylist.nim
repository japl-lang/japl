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

# WIP - Not working

import ../meta/valueobject
import objecttype
import exceptions
import ../memory


type ArrayList = object
    size*: int
    capacity*: int
    container*: ptr UncheckedArray[Value]


proc append*(self: var ArrayList, elem: Value) =
    if self.capacity < self.size + 1:
        self.capacity = growCapacity(self.capacity)
        self.container = resizeArray(UncheckedArray[Value], self.container, sizeof(Value) * self.size, sizeof(Value) * self.capacity)
    self.container[self.size] = elem
    self.size += 1


proc pop*(self: var ArrayList, idx: int = -1): Value =
    var idx = idx
    if self.size == 0:
        echo stringify(newTypeError("pop from empty list"))
        return
    elif idx == -1:
        idx = self.size
    if idx notin 0..self.size:
       echo stringify(newTypeError("list index out of bounds"))
       return
    else:
        var elem = self.container[idx]
        if idx != self.size:
            self.container = resizeArray(UncheckedArray[Value], self.container, self.capacity - 1, self.capacity)
        self.size -= 1
        self.capacity -= 1


proc newArrayList*(): ArrayList =
    result = ArrayList(size: 0, capacity: 0, container: resizeArray(UncheckedArray[Value], nil, 0, 0))


proc `$`*(self: ArrayList): string =
    result = "["
    if self.size > 0:
        for i in 0..self.size:
            result = result & stringify(self.container[i])
            result = result & ", "
    result = result & "]"


var lst = newArrayList()
echo $lst
lst.append(1.asInt())
echo $lst
