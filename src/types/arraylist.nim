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

# Implementation of a custom list data type for JAPL objects (used also internally by the VM)

{.experimental: "implicitDeref".}
import iterable
import ../memory
import baseObject
import strformat


type ArrayList*[T] = object of Iterable
    ## Implementation of a simple dynamic
    ## array with amortized O(1) append complexity
    ## and O(1) complexity when popping/deleting
    ## the last element
    container*: ptr UncheckedArray[T]


proc newArrayList*[T](): ptr ArrayList[T] =
    ## Allocates a new, empty array list
    result = allocateObj(ArrayList[T], ObjectType.List)
    result.capacity = 0
    result.container = nil
    result.length = 0


proc append*[T](self: ptr ArrayList[T], elem: T) =
    ## Appends an object to the end of the list
    ## in amortized constant time (~O(1))
    if self.capacity <= self.length:
        self.capacity = growCapacity(self.capacity)
        self.container = resizeArray(T, self.container, self.length, self.capacity)            
    self.container[self.length] = elem
    self.length += 1


proc pop*[T](self: ptr ArrayList[T], idx: int = -1): T =
    ## Pops an item from the list. By default, the last
    ## element is popped, in which case the operation's
    ## time complexity is O(1). When an arbitrary element
    ## is popped, the complexity rises to O(k) where k
    ## is the number of elements that had to be shifted
    ## by 1 to avoid empty slots
    var idx = idx
    if self.length == 0:
        raise newException(IndexDefect, "pop from empty ArrayList")
    if idx == -1:
        idx = self.length - 1
    if idx notin 0..self.length - 1:
        raise newException(IndexDefect, &"ArrayList index out of bounds: {idx} notin 0..{self.length - 1}")
    result = self.container[idx]
    if idx != self.length - 1:
        for i in countup(idx, self.length - 1):
            self.container[i] = self.container[i + 1]
        self.capacity -= 1
    self.length -= 1


proc `[]`*[T](self: ptr ArrayList[T], idx: int): T =
    ## Retrieves an item from the list, in constant
    ## time
    if self.length == 0:
        raise newException(IndexDefect, &"ArrayList index out of bounds: : {idx} notin 0..{self.length - 1}")
    if idx notin 0..self.length - 1:
        raise newException(IndexDefect, &"ArrayList index out of bounds: {idx} notin 0..{self.length - 1}")
    result = self.container[idx]


proc `[]`*[T](self: ptr ArrayList[T], slice: Hslice[int, int]): ptr ArrayList[T] =
    ## Retrieves a subset of the list, in O(k) time where k is the size
    ## of the slice
    if self.length == 0:
        raise newException(IndexDefect, "ArrayList index out of bounds")
    if slice.a notin 0..self.length - 1 or slice.b notin 0..self.length:
        raise newException(IndexDefect, "ArrayList index out of bounds")
    result = newArrayList[T]()
    for i in countup(slice.a, slice.b - 1):
        result.append(self.container[i])


proc `[]=`*[T](self: ptr ArrayList[T], idx: int, obj: T) =
    ## Assigns an object to the given index, in constant
    ## time
    if self.length == 0:
        raise newException(IndexDefect, "ArrayList is empty")
    if idx notin 0..self.length - 1:
        raise newException(IndexDefect, "ArrayList index out of bounds")
    self.container[idx] = obj


proc delete*[T](self: ptr ArrayList[T], idx: int) =
    ## Deletes an object from the given index.
    ## This method shares the time complexity
    ## of self.pop()
    if self.length == 0:
        raise newException(IndexDefect, "delete from empty ArrayList")
    if idx notin 0..self.length - 1:
        raise newException(IndexDefect, &"ArrayList index out of bounds: {idx} notin 0..{self.length - 1}")
    discard self.pop(idx)


proc contains*[T](self: ptr ArrayList[T], elem: T): bool = 
    ## Returns true if the given object is present
    ## in the list, false otherwise. O(n) complexity
    if self.length > 0:
        for i in 0..self.length - 1:
            if self[i] == elem:
                return true
    return false


proc high*[T](self: ptr ArrayList[T]): int = 
    ## Returns the index of the last
    ## element in the list, in constant time
    if self.length == 0:
        raise newException(IndexDefect, "ArrayList is empty")
    result = self.length - 1


proc len*[T](self: ptr ArrayList[T]): int = 
    ## Returns the length of the list
    ## in constant time
    result = self.length


iterator pairs*[T](self: ptr ArrayList[T]): tuple[key: int, val: T] =
    ## Implements pairwise iteration (similar to python's enumerate)
    for i in countup(0, self.length - 1):
        yield (key: i, val: self[i])


iterator items*[T](self: ptr ArrayList[T]): T =
    ## Implements iteration
    for i in countup(0, self.length - 1):
        yield self[i]


proc reversed*[T](self: ptr ArrayList[T], first: int = -1, last: int = 0): ptr ArrayList[T] =
    ## Returns a reversed version of the given list, from first to last.
    ## First defaults to -1 (the end of the list) and last defaults to 0 (the
    ## beginning of the list)
    var first = first
    if first == -1:
        first = self.length - 1
    result = newArrayList[T]()
    for i in countdown(first, last):
        result.append(self[i])


proc extend*[T](self: ptr ArrayList[T], other: seq[T]) =
    ## Iteratively calls self.append() with the elements
    ## from a nim sequence
    for elem in other:
        self.append(elem)


proc extend*[T](self: ptr ArrayList[T], other: ptr ArrayList[T]) =
    ## Iteratively calls self.append() with the elements
    ## from another ArrayList
    for elem in other:
        self.append(elem)


proc `$`*[T](self: ptr ArrayList[T]): string =
    ## Returns a string representation
    ## of self
    result = "["
    if self.length > 0:
        for i in 0..self.length - 1:
            result = result & $self.container[i]
            if i < self.length - 1:
                result = result & ", "
    result = result & "]"


proc getIter*[T](self: ptr ArrayList[T]): Iterator = 
    ## Returns the iterator object of the
    ## arraylist
    result = allocate(Iterator, )
