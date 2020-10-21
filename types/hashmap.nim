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
import ../memory
import stringtype
import objecttype
import lenientops


const HASH_MAP_LOAD_MAX = 0.75   # Hash map max load factor

type
    Entry = ref object
        key*: Value
        value*: Value

    HashMap = ref object of Obj
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


proc findEntry(self: HashMap, key: Value): Entry =
    var idx = (int key.hash) mod self.capacity
    var entry: Entry
    while true:
        entry = self.entries[idx]
        if valuesEqual(entry.key, key) or entry.key == nil:
            result = entry
            break
        idx = idx + 1 mod self.capacity


proc adjustCapacity(self: HashMap, capacity: int) =
    var entries = cast[ptr UncheckedArray[Entry]](allocate(Entry, capacity))
    var i = 0
    while i < capacity:
        entries[i].key = nil
        entries[i].value = Value(kind: NIL)
        i += 1
    self.entries = entries
    self.capacity = capacity


proc setEntry(self: HashMap, key: Value, value: Value): bool =
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
