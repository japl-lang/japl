# Errors for JAPL

import valueobject

type
    JAPLException* = ref object of Obj
        name*: Obj


proc newTypeError*(): JAPLException =
    result = JAPLException(name: Obj(kind: ObjectTypes.STRING, str: "TypeError"))


