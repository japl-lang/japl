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


import tables
import strutils
import meta/valueobject
import meta/tokenobject
import types/objecttype


const FRAMES_MAX* = 400  # TODO: Inspect why the VM crashes if this exceeds 400
const JAPL_VERSION* = "0.2.0"
const JAPL_RELEASE* = "alpha"
const DEBUG_TRACE_VM* = true   # Traces VM execution
const DEBUG_TRACE_GC* = true    # Traces the garbage collector (TODO)
const DEBUG_TRACE_ALLOCATION* = true   # Traces memory allocation/deallocation (WIP)
const DEBUG_TRACE_COMPILER* = true   # Traces the compiler (TODO)


type
    CallFrame* = ref object    # FIXME: Call frames are broken (end indexes are likely wrong)
        function*: ptr Function
        ip*: int
        slot*: int
        endSlot*: int
        stack*: seq[Value]

    VM* = ref object    # The VM object
        lastPop*: Value
        frameCount*: int
        source*: string
        frames*: seq[CallFrame]
        stack*: seq[Value]
        stackTop*: int
        objects*: seq[ptr Obj]
        globals*: Table[string, Value]
        file*: string

    Local* = ref object   # A local variable
       name*: Token
       depth*: int


    Parser* = ref object  # A Parser object
        current*: int
        tokens*: seq[Token]
        hadError*: bool
        panicMode*: bool
        file*: string


proc getView*(self: CallFrame): seq[Value] =
    result = self.stack[self.slot..self.endSlot - 1]


proc getAbsIndex(self: CallFrame, idx: int): int =
    return idx + len(self.getView()) - 1   # TODO: Inspect this code (locals, functions)


proc len*(self: CallFrame): int =
    result = len(self.getView())


proc `[]`*(self: CallFrame, idx: int): Value =
    result = self.stack[self.getAbsIndex(idx)]


proc `[]=`*(self: CallFrame, idx: int, val: Value) =
    if idx < self.slot:
        raise newException(IndexError, "CallFrame index out of range")
    self.stack[self.getAbsIndex(idx)] = val


proc delete*(self: CallFrame, idx: int) =
    if idx < self.slot or idx > self.endSlot:
        raise newException(IndexError, "CallFrame index out of range")
    self.stack.delete(idx)


func stringify*(value: Value): string =
    case value.kind:
        of INTEGER:
            result = $value.toInt()
        of DOUBLE:
            result = $value.toFloat()
        of BOOL:
            result = $value.toBool()
        of NIL:
            result = "nil"
        of OBJECT:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).stringify
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).stringify
                else:
                    result = value.obj.stringify()
        of ValueType.Nan:
            result = "nan"
        of ValueType.Inf:
            result = "inf"
        of MINF:
            result = "-inf"


## TODO: Move this stuff back to their respective module

proc initParser*(tokens: seq[Token], file: string): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false, file: file)


proc hashFloat(f: float): uint32 =
    # TODO: Any improvement?
    result = 2166136261u32
    result = result xor uint32 f
    result *= 16777619


# TODO: Move this into an hash() method for objects
proc hash*(value: Value): uint32 =
    case value.kind:
        of INTEGER:
            result = uint32 value.toInt()
        of BOOL:
            if value.boolValue:
                result = uint32 1
            else:
                result = uint32 0
        of DOUBLE:
            result = hashFloat(value.toFloat())
        of OBJECT:
            case value.obj.kind:
                of ObjectType.String:
                    result = hash(cast[ptr String](value.obj))
                else:
                    result = hash(value.obj)
        else:   # More coming soon
            result = uint32 0


# TODO: Move this into a bool() method for objects
func isFalsey*(value: Value): bool =
    case value.kind:
        of BOOL:
            result = not value.toBool()
        of OBJECT:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).isFalsey()
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).isFalsey()
                else:
                    result = isFalsey(value.obj)
        of INTEGER:
            result = value.toInt() == 0
        of DOUBLE:
            result = value.toFloat() == 0.0
        of NIL:
            result = true
        of ValueType.Inf, ValueType.Minf:
            result = false
        of ValueType.Nan:
            result = true


# TODO: Move this to a toString() method for objects
func typeName*(value: Value): string =
    case value.kind:
        of ValueType.Bool, ValueType.Nil, ValueType.Double,
          ValueType.Integer, ValueType.Nan, ValueType.Inf:
            result = ($value.kind).toLowerAscii()
        of MINF:
           result = "inf"
        of OBJECT:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).typeName()
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).typeName()
                else:
                    result = value.obj.typeName()

# TODO: Move this to a eq() method for objects
proc valuesEqual*(a: Value, b: Value): bool =
    if a.kind != b.kind:
        result = false
    else:
        case a.kind:
            of BOOL:
                result = a.toBool() == b.toBool()
            of NIL:
                result = true
            of INTEGER:
                result = a.toInt() == b.toInt()
            of DOUBLE:
                result = a.toFloat() == b.toFloat()
            of OBJECT:
                case a.obj.kind:
                    of ObjectType.String:
                        var a = cast[ptr String](a.obj)
                        var b = cast[ptr String](b.obj)
                        result = valuesEqual(a, b)
                    of ObjectType.Function:
                        var a = cast[ptr Function](a.obj)
                        var b = cast[ptr Function](b.obj)
                        result = valuesEqual(a, b)
                    else:
                        result = valuesEqual(a.obj, b.obj)
            of ValueType.Inf:
                result = b.kind == ValueType.Inf
            of MINF:
                result = b.kind == ValueType.Minf
            of ValueType.Nan:
                result = false

