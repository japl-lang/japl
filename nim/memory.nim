## This module handles all memory allocation and deallocation for the entire
## JAPL runtime. Forcing the entire language to route memory allocation
## into a single module makes it easy to track how much memory we have allocated
## and simplifies the implementation of a garbage collector.
## To also make our life as language implementers easier, the internals of the
## interpreter (which means the tokenizer, the compiler the debugger,
## and some parts of the Virtual Machine) will use nim's GC


import segfaults
import types/objecttype


proc reallocate*(pointer: pointer, oldSize: int, newSize: int): pointer =
    try:
        if newSize == 0 and pointer != nil:
            dealloc(pointer)
            return nil
        result = realloc(pointer, newSize)
    except NilAccessError:
        echo "A fatal error occurred -> could not allocate memory, segmentation fault"
        quit(71)


template resizeArray*(kind: untyped, pointer: pointer, oldCount, newCount: int): untyped =
    cast[ptr kind](reallocate(pointer, sizeof(kind) * oldCount, sizeof(kind) * newCount))


template freeArray*(kind: untyped, pointer: pointer, oldCount: int): untyped =
    reallocate(pointer, sizeof(kind) * oldCount, 0)


template free*(kind: untyped, pointer: pointer): untyped =
    reallocate(pointer, sizeof(kind), 0)


template growCapacity*(capacity: int): untyped =
    if capacity < 8:
        8
    else:
        capacity * 2


template allocate*(castTo: untyped, sizeTo: untyped, count: int): untyped =
    cast[ptr castTo](reallocate(nil, 0, sizeof(sizeTo) * count))


proc allocateObject*(size: int, kind: ObjectType): ptr Obj =
    result = cast[ptr Obj](reallocate(nil, 0, size))
    result.kind = kind



template allocateObj*(kind: untyped, objType: ObjectType): untyped =
    cast[ptr kind](allocateObject(sizeof kind, objType))
