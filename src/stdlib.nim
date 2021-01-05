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

import vm
import types/native
import types/baseObject
import types/japlNil
import types/numbers
import types/methods
import times



proc natPrint(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] =
    ## Native function print
    ## Prints an object representation
    ## to stdout. If more than one argument
    ## is passed, they will be printed separated
    ## by a space
    var res = ""
    for i in countup(0, args.high()):
        let arg = args[i]
        if i < args.high():
            res = res & arg.stringify() & " "
        else:
            res = res & arg.stringify()
    echo res
    return (ok: true, result: asNil())


proc natClock(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] =
    ## Native function clock
    ## Returns the current unix
    ## time (also known as epoch)
    ## with subsecond precision

    # TODO: Move this to a separate module once we have imports

    result = (ok: true, result: getTime().toUnixFloat().asFloat())


template stdlibInit*(vm: VM) =
    vm.defineGlobal("print", newNative("print", natPrint, -1))
    vm.defineGlobal("clock", newNative("clock", natClock, 0))
