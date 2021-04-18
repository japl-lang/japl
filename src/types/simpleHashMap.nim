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


# This module implements a very simple associative array meant for internal
# use by the JAPL runtime. This "version" of the HashMap object is optimized
# to store JAPL objects only and to not use anything from nim's stdlib other
# than the system module. For a documented & more flexible hashmap type
# check src/types/hashMap.nim


import ../memory
import ../config
import baseObject
import methods
import iterable


type
    SimpleEntry = object
        key: ptr Obj
        value: ptr Obj
        tombstone: bool
    SimpleHashMap* = object of Iterable
        entries: ptr UncheckedArray[ptr SimpleEntry]
        actual_length: int


proc newSimpleHashMap*(): ptr SimpleHashMap =
    result = allocateObj(SimpleHashMap, ObjectType.Dict)
    result.actual_length = 0
    result.entries = nil
    result.capacity = 0
    result.length = 0


proc freeSimpleHashMap*(self: ptr SimpleHashMap) =
    discard freeArray(UncheckedArray[ptr SimpleEntry], self.entries, self.capacity)
    self.length = 0
    self.actual_length = 0
    self.capacity = 0
    self.entries = nil


proc findEntry(self: ptr UncheckedArray[ptr SimpleEntry], key: ptr Obj, capacity: int): ptr SimpleEntry =
    var capacity = uint64(capacity)
    var idx = uint64(key.hash()) mod capacity
    while true:
        result = self[idx]
        if system.`==`(result.key, nil) or result.tombstone:
            break
        elif result.key == key:
            break
        idx = (idx + 1) mod capacity


proc adjustCapacity(self: ptr SimpleHashMap) =
    var newCapacity = growCapacity(self.capacity)
    var entries = allocate(UncheckedArray[ptr SimpleEntry], SimpleEntry, newCapacity)
    var oldEntry: ptr SimpleEntry
    var newEntry: ptr SimpleEntry
    self.length = 0
    for x in countup(0, newCapacity - 1):
        entries[x] = allocate(SimpleEntry, SimpleEntry, 1)
        entries[x].tombstone = false
        entries[x].key = nil
        entries[x].value = nil
    for x in countup(0, self.capacity - 1):
        oldEntry = self.entries[x]
        if not system.`==`(oldEntry.key, nil):
            newEntry = entries.findEntry(oldEntry.key, newCapacity)
            newEntry.key = oldEntry.key
            newEntry.value = oldEntry.value
            self.length += 1
    discard freeArray(UncheckedArray[ptr SimpleEntry], self.entries, self.capacity)
    self.entries = entries
    self.capacity = newCapacity


proc setEntry(self: ptr SimpleHashMap, key: ptr Obj, value: ptr Obj): bool =
    if float64(self.length + 1) >= float64(self.capacity) * MAP_LOAD_FACTOR:
        self.adjustCapacity()
    var entry = findEntry(self.entries, key, self.capacity)
    result = system.`==`(entry.key, nil)
    if result:
        self.actual_length += 1
        self.length += 1
    entry.key = key
    entry.value = value
    entry.tombstone = false


proc `[]`*(self: ptr SimpleHashMap, key: ptr Obj): ptr Obj =
    var entry = findEntry(self.entries, key, self.capacity)
    if system.`==`(entry.key, nil) or entry.tombstone:
        raise newException(KeyError, "Key not found: " & $key)
    result = entry.value


proc `[]=`*(self: ptr SimpleHashMap, key: ptr Obj, value: ptr Obj) =
    discard self.setEntry(key, value)


proc len*(self: ptr SimpleHashMap): int =
    result = self.actual_length


proc del*(self: ptr SimpleHashMap, key: ptr Obj) =
    if self.len() == 0:
        raise newException(KeyError, "delete from empty hashmap")
    var entry = findEntry(self.entries, key, self.capacity)
    if not system.`==`(entry.key, nil):
        self.actual_length -= 1
        entry.tombstone = true
    else:
        raise newException(KeyError, "Key not found: " & $key)


proc contains*(self: ptr SimpleHashMap, key: ptr Obj): bool =
    let entry = findEntry(self.entries, key, self.capacity)
    if not system.`==`(entry.key, nil) and not entry.tombstone:
        result = true
    else:
        result = false


iterator keys*(self: ptr SimpleHashMap): ptr Obj =
    var entry: ptr SimpleEntry
    for i in countup(0, self.capacity - 1):
        entry = self.entries[i]
        if not system.`==`(entry.key, nil) and not entry.tombstone:
            yield entry.key


iterator values*(self: ptr SimpleHashMap): ptr Obj =
    for key in self.keys():
        yield self[key]


iterator pairs*(self: ptr SimpleHashMap): tuple[key: ptr Obj, val: ptr Obj] =
    for key in self.keys():
        yield (key: key, val: self[key])


iterator items*(self: ptr SimpleHashMap): ptr Obj =
    for k in self.keys():
        yield k


proc `$`*(self: ptr SimpleHashMap): string =
    var i = 0
    result &= "{"
    for key, value in self.pairs():
        result &= $key & ": " & $value
        if i < self.len() - 1:
            result &= ", "
        i += 1
    result &= "}"
