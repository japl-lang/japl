import ../meta/valueobject
import exceptions
import ../memory


type ArrayList = object
    size: int
    capacity: int
    container: ptr UncheckedArray[Value]


proc append*(self: ArrayList, elem: Value] =
    if self.capacity < self.size + 1:
        self.capacity = growCapacity()
        self.container = cast[ptr UncheckedArray[Value]](resizeArray(UncheckedArray[Value], self.container, self.container.size, sizeof(Value) * self.capacity))
    self.size += 1
    self.container[self.size] = elem


proc pop*(self: ArrayList, idx: int = -1): Value =
    if self.size == 0:
        echo stringify(newTypeError("pop from empty list"))
        return
    elif idx == -1:
        idx = self.size
    if idx notin 0..self.size:
       echo stringify(newTypeError("list index out of bounds"))
       return
    else:
        elem = self.container[idx]
        if idx != self.size:
            self.container = cast[ptr UncheckedArray[Value]](resizeArray(UncheckedArray[Value], self.container, self.container.capacity - 1, self.container.capacity))
        self.size -= 1
        self.capacity -= 1


proc newArrayList*(): ArrayList =
    result = ArrayList(0, 0, nil)



proc `$`(self: ArrayList): string =
    result = result & "["
    var i = self.size
    for i in 0..self.size:
        element = self.container[i]
        result = result & stringify(element)
    result = result & "]"
