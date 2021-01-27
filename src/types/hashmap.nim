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



import ../memory
import ../config
import baseObject
import methods
import iterable


import lenientops
import options
import hashes
import strformat



type
    Entry*[K, V] = object
        ## Low-level object to store key/value pairs
        key*: Option[K]
        value*: Option[V]
        tombstone*: bool
    HashMap*[K, V] = object of Iterable
        ## An associative array with O(1) lookup time,
        ## similar to nim's Table type, but using raw
        ## memory to be more compatible with JAPL's runtime
        ## memory management
        entries*: ptr UncheckedArray[ptr Entry[K, V]]
        # This attribute counts *only* non-deleted entries
        actual_length*: int


proc newHashMap*[K, V](): ptr HashMap[K, V] =
    ## Initializes a new, empty hashmap
    result = allocateObj(HashMap[K, V], ObjectType.Dict)
    result.actual_length = 0
    result.entries = nil
    result.capacity = 0
    result.length = 0


proc freeHashMap*[K, V](self: ptr HashMap[K, V]) =
    ## Frees the memory associated with the hashmap
    discard freeArray(UncheckedArray[ptr Entry[K, V]], self.entries, self.capacity)
    self.length = 0
    self.actual_length = 0
    self.capacity = 0
    self.entries = nil


proc findEntry[K, V](self: ptr UncheckedArray[ptr Entry[K, V]], key: K, capacity: int): ptr Entry[K, V] =
    ## Low-level method used to find entries in the underlying
    ## array, returns a pointer to an entry
    var capacity = uint64(capacity)
    var idx = uint64(key.hash()) mod capacity
    var tombstone: ptr Entry[K, V] = nil
    while true:
        result = self[idx]
        if result.key.isNone() and result.key.isSome():
            # We found a tombstone
            tombstone = result
        elif result.key.isNone() or result.key.get() == key:
            if tombstone != nil:
                result = tombstone
                result.tombstone = true
            break
        # If none of these conditions match, we have a collision!
        # This means we can just move on to the next slot in our probe
        # sequence until we find an empty slot. The way our resizing
        # mechanism works makes the empty slot invariant easy to 
        # maintain since we increase the underlying array's size 
        # before we are actually full
        idx += 1 mod capacity


proc adjustCapacity[K, V](self: ptr HashMap[K, V]) =
    ## Adjusts the capacity of the underlying array to make room
    ## for more entries. Low-level method, not recommended
    var newCapacity = growCapacity(self.capacity)
    var entries = allocate(UncheckedArray[ptr Entry[K, V]], Entry[K, V], newCapacity)
    self.length = 0
    var temp: ptr Entry[K, V]
    for x in countup(0, newCapacity - 1):
        entries[x] = allocate(Entry[K, V], Entry[K, V], 1)
        temp = entries[x]
        temp.key = none(K)
        temp.value = none(V)
        temp.tombstone = false
    for x in countdown(self.capacity - 1, 0):
        temp = self.entries[x]
        if temp.key.isSome():
            entries[x] = temp
            self.length += 1
    discard freeArray(UncheckedArray[ptr Entry[K, V]], self.entries, self.capacity)
    self.entries = entries
    self.capacity = newCapacity


proc setEntry[K, V](self: ptr HashMap[K, V], key: K, value: V): bool =
    ## Low-level method to set/replace an entry with a value
    if self.length + 1 > self.capacity * MAP_LOAD_FACTOR:
        # Since we always need at least some empty slots
        # for our probe sequences to work properly, we
        # always resize our underlying array before we're full.
        # MAP_LOAD_FACTOR is a constant float between 0.0 and 1.0
        # which determines the percentage of full buckets that's
        # needed to start a resize operation
        self.adjustCapacity()
    var entry = findEntry(self.entries, key, self.capacity)
    result = entry.key.isNone()
    if result:
        self.actual_length += 1
        self.length += 1
    entry.key = some(key)
    entry.value = some(value)


proc `[]`*[K, V](self: ptr HashMap[K, V], key: K): V = 
    ## Retrieves a value by key
    var entry = findEntry(self.entries, key, self.capacity)
    if entry.key.isNone():
        raise newException(KeyError, &"Key not found: {key}")
    result = entry.value.get()


proc `[]=`*[K, V](self: ptr HashMap[K, V], key: K, value: V) = 
    ## Sets a value with the given key. If the key already
    ## exists it will be overwritten
    discard self.setEntry(key, value)


proc del*[K, V](self: ptr HashMap[K, V], key: K) = 
    ## Deletes an entry in the hashmap
    if self.len() == 0:
        raise newException(KeyError, &"delete from empty hashmap")
    var entry = findEntry(self.entries, key, self.capacity)
    if entry.key.isSome():
        ## We don't reset the value of the
        ## 'value' attribute because that 
        ## makes us understand that this
        ## entry is a tombstone and not
        ## a truly full bucket
        self.actual_length -= 1
        entry.key = none(K)
    else:
        raise newException(KeyError, &"Key not found: {key}")


proc contains*[K, V](self: ptr HashMap[K, V], key: K): bool =
    ## Checks if key is in the hashmap
    var entry = findEntry(self.entries, key, self.capacity)
    if entry.key.isSome():
        result = true
    else:
        result = false


iterator keys*[K, V](self: ptr HashMap[K, V]): K = 
    ## Yields all the keys in the hashmap
    var entry: ptr Entry[K, V]
    for i in countup(0, self.capacity - 1):
        entry = self.entries[i]
        if entry.key.isSome():
            yield entry.key.get()


iterator values*[K, V](self: ptr HashMap[K, V]): V = 
    ## Yields all the values in the hashmap
    for key in self.keys():
        yield self[key]


iterator pairs*[K, V](self: ptr HashMap[K, V]): tuple[key: K, val: V] = 
    ## Yields all the key/value pairs in the hashmap
    for key in self.keys():
        yield (key: key, val: self[key])


iterator items*[K, V](self: ptr HashMap[K, V]): K = 
    ## Yields all the keys in the hashmap (for iteration)
    for k in self.keys():
        yield k


proc len*[K, V](self: ptr HashMap[K, V]): int = 
    ## Returns the length of the hashmap
    result = self.actual_length


proc `$`*[K, V](self: ptr HashMap[K, V]): string = 
    ## Returns a string representation of the hashmap
    var i = 0
    result &= "{"
    for key, value in self.pairs():
        result &= &"{key}: {value}"
        if i < self.len() - 1:
            result &= ", "
        i += 1
    result &= "}"


var d = newHashMap[int, int]()
d[1] = 55
d[2] = 876
d[3] = 7890
d[4] = 55
d[5] = 435
d[6] = 567
d[7] = 21334   ## Adjust capacity (75% full)
d[8] = 9768
d[9] = 235
echo d
