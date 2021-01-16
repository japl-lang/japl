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

## Utilities to inspect JAPL objects

import baseObject


type 
    returnTypes* {.pure.} = enum
        ## Pretty much like retNative, we use
        ## this handy enum to differentiate
        ## what is what, perform better error
        ## handling and (most importantly)
        ## maintain our invariant that singletons
        ## always refer to the same object
        False,
        True,
        Inf,
        nInf,
        Nil,
        NotANumber,
        Object,
        Exception
    returnType* = tuple[kind: returnTypes, result: ptr Obj]



proc objType*(obj: ptr Obj): ObjectType =
    ## Returns the type of the object
    result = obj.kind


proc isCallable*(obj: ptr Obj): bool =
    ## Returns true if the given object
    ## is callable, false otherwise
    result = obj.kind in {ObjectType.Function, ObjectType.Class, ObjectType.Native}


proc isNil*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL nil object
    result = obj.kind == ObjectType.Nil


proc isBool*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL bool
    result = obj.kind == ObjectType.Bool


proc isInt*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL integer
    result = obj.kind == ObjectType.Integer


proc isFloat*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL float
    result = obj.kind == ObjectType.Float


proc isInf*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL inf object
    result = obj.kind == ObjectType.Infinity


proc isNan*(obj: ptr Obj): bool =
    ## Returns true if the given obj
    ## is a JAPL nan object
    result = obj.kind == ObjectType.NotANumber


proc isNum*(obj: ptr Obj): bool =
    ## Returns true if the given obj is
    ## either a JAPL number, infinity or nan.
    ## Note to JavaScript developers: No, in JAPL
    ## nan is not a number. Here we consider it like
    ## a number because internally it's easier to
    ## represent it like that for methods that perform
    ## binary operations on numbers, since 2 * nan is 
    ## valid JAPL code and will yield nan
    result = isInt(obj) or isFloat(obj) or isInf(obj) or isNan(obj)


proc isStr*(obj: ptr Obj): bool =
    ## Returns true if the given object is a JAPL string
    result = obj.kind == ObjectType.String
