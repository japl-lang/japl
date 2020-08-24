import ../meta/valueobject
import exceptions
import ../memory


type ArrayList = object
    size*: int
    capacity*: int
    container*: ptr UncheckedArray[Value]


proc append*(self: var ArrayList, elem: Value) =
    if self.capacity < self.size + 1:
        self.capacity = growCapacity(self.capacity)
        self.container = cast[ptr UncheckedArray[Value]](resizeArray(ptr UncheckedArray[Value], self.container, self.size, sizeof(Value) * self.capacity))
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
            self.container = cast[ptr UncheckedArray[Value]](resizeArray(ptr UncheckedArray[Value], self.container, self.capacity - 1, self.capacity))
        self.size -= 1
        self.capacity -= 1


proc newArrayList*(): ArrayList =
    result = ArrayList(size: 0, capacity: 0, container: nil)



proc `$`*(self: ArrayList): string =
    result = result & "["
    var i = self.size
    var element: Value
    if self.size > 0:
        for i in 0..self.size:
            element = self.container[i]
            result = result & stringify(element)
    result = result & "]"


var lst = newArrayList()
echo $lst
lst.append(1.asInt())
echo $lst
