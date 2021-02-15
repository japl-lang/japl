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

# Implementations of builtin functions and modules

import types/baseObject
import types/numbers
import types/methods
import types/typeutils
import types/japlString
import types/exception
import types/native

import times
import math
import strformat
import parseutils
import strutils

template join(args: seq[ptr Obj]): string =
    ## A template that returns the string
    ## representation of all args separated
    ## by a space.
    var res = ""
    for i in countup(0, args.high()):
        let arg = args[i]
        if i < args.high():
            res = res & arg.stringify() & " "
        else:
            res = res & arg.stringify()
    res

proc natPrint*(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj] =
    ## Native function print
    ## Prints an object representation
    ## to stdout. If more than one argument
    ## is passed, they will be printed separated
    ## by a space
    # Note: we return nil and not asNil() because
    # the VM will later use its own cached pointer
    # to nil
    echo join(args)
    return (kind: retNative.Nil, result: nil)

proc natPrintErr*(args: seq[ptr Obj]): tuple[kind:
  retNative, result: ptr Obj] =
    ## Native function printErr
    ## Prints an object representation
    ## to stderr. If more than one argument
    ## is passed, they will be printed separated
    ## by a space
    writeLine stderr, join(args)
    return (kind: retNative.Nil, result: nil)

proc natReadline*(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj] =
    ## Native function readline
    ## Reads a line from stdin and returns
    ## it as a string, optionally writing
    ## a given prompt to stdout
    if args.len() > 1:
        return (kind: retNative.Exception, result: newTypeError(&"Function 'readLine' takes 0 to 1 arguments, got {len(args)}"))
    elif args.len() > 0 and not args[0].isStr():
        return (kind: retNative.Exception, result: newTypeError(&"The prompt must be of type 'string', not '{args[0].typeName()}'"))
    if args.len() > 0:
        stdout.write(args[0].toStr())
    return (kind: retNative.Object, result: stdin.readLine().asStr())


proc natClock*(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj] =
    ## Native function clock
    ## Returns the current unix
    ## time (also known as epoch)
    ## with subsecond precision

    # TODO: Move this to a separate module once we have imports

    result = (kind: retNative.Object, result: getTime().toUnixFloat().asFloat())


proc natRound*(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj] =
    ## Rounds a floating point number to a given
    ## precision (when precision == 0, this function drops the
    ## decimal part and returns an integer). Note that when
    ## precision > 0 and the value of the dropped digits
    ## exceeds or equals 5, the closest decimal place is
    ## increased by 1 (i.e. round(3.141519, 3) == 3.142)
    var precision = 0
    if len(args) notin 1..2:
        # Here we need to return immediately to exit the procedure
        return (kind: retNative.Exception, result: newTypeError(&"function 'round' takes from 1 to 2 arguments, got {len(args)}"))
    elif len(args) == 2:
        if not args[1].isInt():
            return (kind: retNative.Exception, result: newTypeError(&"precision must be of type 'int', not '{args[1].typeName()}'"))
        else:
            precision = args[1].toInt()
    if args[0].kind notin {ObjectType.Integer, ObjectType.Float}:
        return (kind: retNative.Exception, result: newTypeError(&"input must be of type 'int' or 'float', not '{args[0].typeName()}'"))
    if precision < 0:
        result = (kind: retNative.Exception, result: newTypeError(&"precision must be positive"))
    else:
        if args[0].isInt():
            result = (kind: retNative.Object, result: args[0])
        elif precision == 0:
            result = (kind: retNative.Object, result: int(args[0].toFloat()).asInt())
        else:
            result = (kind: retNative.Object, result: round(args[0].toFloat(), precision).asFloat())


proc natToInt*(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj] =
    ## Drops the decimal part of a float and returns an integer or
    ## converts an integer string to an actual integer object.
    ## If the value is already an integer, the same object is returned
    if args[0].isInt():
        result = (kind: retNative.Object, result: args[0])
    elif args[0].isFloat():
        result = (kind: retNative.Object, result: int(args[0].toFloat()).asInt())
    elif args[0].isStr():
        let s = args[0].toStr()
        for c in s:
            if not c.isDigit():
                return (kind: retNative.Exception, result: newValueError("invalid argument"))
        try:
            var num: int
            discard parseInt(args[0].toStr(), num)
            result = (kind: retNative.Object, result: num.asInt())
        except ValueError:
            result = (kind: retNative.Exception, result: newValueError("invalid argument"))
    else:
        result = (kind: retNative.Exception, result: newTypeError(&"input must be of type 'int', 'float' or 'string', not '{args[0].typeName()}'"))


proc natType*(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj] =
    ## Returns the type of a given object as a string
    result = (kind: retNative.Object, result: args[0].typeName().asStr())


proc natToString*(args: seq[ptr Obj]): tuple[kind: retNative, result: ptr Obj] =
    ## Returns the string representation of an object
    result = (kind: retNative.Object, result: args[0].stringify().asStr())
