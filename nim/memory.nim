# This module handles all memory allocation and deallocation for the entire
# JAPL runtime. Forcing the entire language to route memory allocation
# into a single module makes it easy to track how much memory we have allocated
# and simplifies the implementation of a garbage collector.
# To also make our life as language implementers easier, the internals of the
# interpreter (which means the tokenizer, the compiler the debugger,
# and some parts of the Virtual Machine) will use nim's GC


import types/objecttype


proc reallocate*(pointer: pointer, oldSize: int, newSize: int): pointer =
    if newSize == 0 and pointer != nil:
        dealloc(pointer)
        return nil
    var res = realloc(pointer, newSize)
    result = res


template resizeArray*(kind: untyped, pointer: pointer, oldCount, newCount: int): untyped =
    cast[kind](reallocate(pointer, sizeof(kind) * oldCount, sizeof(kind) * newCount))


template freeArray*(kind: untyped, pointer: ptr, oldCount: int): untyped =
    reallocate(pointer, syzeof(kind) * oldCount, 0)


template growCapacity*(cap: int): untyped =
    if capacity < 8:
        8
    else:
        capacity * 2


proc allocateObject*(size: int, kind: ObjectTypes): ptr Obj =
    var obj = cast[Obj](reallocate(nil, 0, size))
    obj.kind = kind
    result = addr obj


template allocate*(kind: untyped, count: int): untyped =
    cast[ptr kind](reallocate(nil, 0, sizeof(kind) * count))
