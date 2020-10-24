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


func stringify(obj: ptr Obj): string = 
    ## Returns a string representation of an object
    result = convert(obj).stringify()


func isFalsey*(obj: ptr Obj): bool =
    case obj.kind:
        of ObjectType.String:
            result = cast[ptr String](value.obj).isFalsey()
        of ObjectType.Function:
            result = cast[ptr Function](value.obj).isFalsey()
        of ObjectType.Exception:
            result = cast[ptr JaplException](value.obj).isFalsey()
        of ObjectType.Class:
            discard # TODO Class
        of ObjectType.Module:
            discard # TODO Module
        of ObjectType.BaseObject:
            result = cast[ptr BaseObject](value.obj).isFalsey() # TODO BaseObject


func typeName*(obj: ptr Obj): string =
    ## Returns the name of the type of the object
    case obj.kind:
        of ObjectType.String:
            result = cast[ptr String](obj).typeName()
        of ObjectType.Function:
            result = cast[ptr Function](obj).typeName()
        else:
            result = "" # TODO unimplemented


proc eq*(a: ptr Obj, b: ptr Obj): bool =
    if a.kind != b.kind:
        result = false
    else:
        case a.kind:
            of ObjectType.String:
                var a = cast[ptr String](a)
                var b = cast[ptr String](b)
                result = eq(a, b)
            of ObjectType.Function:
                var a = cast[ptr Function](a)
                var b = cast[ptr Function](b)
                result = eq(a, b)
            else:
                discard  # TODO: Implement
