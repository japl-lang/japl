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


# WIP - Not working

import ../memory
import lenientops
import baseObject
import methods
import japlNil
import japlString


const HASH_MAP_LOAD_MAX = 0.75   # Hash map max load factor


type
    Entry = ref object
        key*: ptr Obj
        value*: ptr Obj
    HashMap = object of Obj
        size*: int
        capacity*: int
        entries*: ptr UncheckedArray[Entry]


proc newHashMap(): HashMap =
    result = HashMap(size: 0, capacity: 0, entries: nil)


proc freeHashMap(self: var HashMap) =
    discard freeArray(self, self.entries, self.capacity)
    self.size = 0
    self.capacity = 0
    self.entries = nil


proc findEntry(self: HashMap, key: ptr Obj): Entry =
    var idx = (int key.hashValue) mod self.capacity
    var entry: Entry
    while true:
        entry = self.entries[idx]
        if entry.key.eq(key) or entry.key == nil:
            result = entry
            break
        idx = idx + 1 mod self.capacity


proc adjustCapacity(self: var HashMap, capacity: int) =
    var entries = allocate(UncheckedArray[Entry], Entry, capacity)
    var i = 0
    while i < capacity:
        entries[i].key = nil
        entries[i].value = cast[ptr Obj](asNil())
        i += 1
    self.entries = entries
    self.capacity = capacity


proc setEntry(self: var HashMap, key: ptr Obj, value: ptr Obj): bool =
    if self.size + 1 > self.capacity * HASH_MAP_LOAD_MAX:
        var capacity = growCapacity(self.capacity)
        self.adjustCapacity(capacity)
    var entry: Entry = self.findEntry(key)
    var isNewKey: bool = entry.key == nil
    if isNewKey:
        self.size += 1
    entry.key = key
    entry.value = value
    result = isNewKey


when isMainModule:
    var dictionary = newHashMap()
    discard dictionary.setEntry(asObj[String]("helo".asStr()), asObj[String]("world".asStr()))
    echo dictionary.findEntry(asObj[String]("helo".asStr())).value.toStr()
