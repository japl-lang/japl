
# this implements stdlib functions for JAPL

import vm
import types/native
import types/baseObject
import types/japlNil
import types/methods

proc natPrint(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] =
    echo args[0].stringify()
    return (ok: true, result: asNil())

template stdlibInit*(vm: VM) =
    vm.defineGlobal("print", newNative("print", natPrint, 1))
