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
 
import japlvalue
import stringtype
import function
import exceptions
import strutils

func stringify*(value: Value): string =
    case value.kind:
        of ValueType.Integer:
            result = $value.toInt()
        of ValueType.Double:
            result = $value.toFloat()
        of ValueType.Bool:
            result = $value.toBool()
        of ValueType.Nil:
            result = "nil"
        of ValueType.Object:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).stringify
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).stringify
                else:
                    result = "TODO this was not implemented"
        of ValueType.Nan:
            result = "nan"
        of ValueType.Inf:
            result = "inf"
        of ValueType.Minf:
            result = "-inf"

func isFalsey*(value: Value): bool =
    case value.kind:
        of ValueType.Bool:
            result = not value.toBool()
        of ValueType.Object:
            case value.obj.kind:
                of ObjectType.String:
                    result = cast[ptr String](value.obj).isFalsey()
                of ObjectType.Function:
                    result = cast[ptr Function](value.obj).isFalsey()
                of ObjectType.Exception:
                    result = cast[ptr JaplException](value.obj).isFalsey()
                of ObjectType.Class:
                    result = cast[ptr JaplException](value.obj).isFalsey() # TODO Class
                of ObjectType.Module:
                    result = cast[ptr JaplException](value.obj).isFalsey() # TODO Module
                of ObjectType.BaseObject:
                    result = cast[ptr JaplException](value.obj).isFalsey() # TODO BaseObject
        of ValueType.Integer:
            result = value.toInt() == 0
        of ValueType.Double:
            result = value.toFloat() == 0.0
        of ValueType.Nil:
            result = true
        of ValueType.Inf, ValueType.Minf:
            result = false
        of ValueType.Nan:
            result = true

func typeName*(obj: ptr Obj): string =
    case obj.kind:
        of ObjectType.String:
            result = cast[ptr String](obj).typeName()
        of ObjectType.Function:
            result = cast[ptr Function](obj).typeName()
        else:
            result = "" # TODO unimplemented

func typeName*(value: Value): string =
    case value.kind:
        of ValueType.Bool, ValueType.Nil, ValueType.Double,
          ValueType.Integer, ValueType.Nan, ValueType.Inf:
            result = ($value.kind).toLowerAscii()
        of ValueType.Minf:
            result = "inf"
        of ValueType.Object:
            result = typeName(value.obj)

proc eq*(a: Value, b: Value): bool =
    if a.kind != b.kind:
        result = false
    else:
        case a.kind:
            of ValueType.Bool:
                result = a.toBool() == b.toBool()
            of ValueType.Nil:
                result = true
            of ValueType.Integer:
                result = a.toInt() == b.toInt()
            of ValueType.Double:
                result = a.toFloat() == b.toFloat()
            of ValueType.Object:
                case a.obj.kind:
                    of ObjectType.String:
                        var a = cast[ptr String](a.obj)
                        var b = cast[ptr String](b.obj)
                        result = eq(a, b)
                    of ObjectType.Function:
                        var a = cast[ptr Function](a.obj)
                        var b = cast[ptr Function](b.obj)
                        result = eq(a, b)
                    else:
                        result = false # TODO unimplemented
                        
            of ValueType.Inf:
                result = b.kind == ValueType.Inf
            of ValueType.Minf:
                result = b.kind == ValueType.Minf
            of ValueType.Nan:
                result = false
  
