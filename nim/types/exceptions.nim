import objecttype
import stringtype
import strformat


type JAPLException* = ref object of Obj
    errName*: ptr String
    message*: ptr String


proc stringify*(self: JAPLException): string =
    return &"{self.errName.str}: {self.message.str}"

proc newTypeError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("TypeError"), message: newString(message))


proc newIndexError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("IndexError"), message: newString(message))


proc newReferenceError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("ReferenceError"), message: newString(message))


proc newInterruptedError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("InterruptedError"), message: newString(message))


