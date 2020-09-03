import objecttype
import stringtype
import strformat
import ../memory


type JAPLException* = object of Obj
    errName*: ptr String
    message*: ptr String


proc stringify*(self: ptr JAPLException): string =
    return &"{self.errName.stringify}: {self.message.stringify}"


proc newTypeError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectTypes.EXCEPTION)
    result.errName = newString("TypeError")
    result.message = newString(message)


proc newIndexError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectTypes.EXCEPTION)
    result.errName = newString("IndexError")
    result.message = newString(message)


proc newReferenceError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectTypes.EXCEPTION)
    result.errName = newString("ReferenceError")
    result.message = newString(message)


proc newInterruptedError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectTypes.EXCEPTION)
    result.errName = newString("InterruptedError")
    result.message = newString(message)


proc newRecursionError*(message: string): ptr JAPLException =
    result = allocateObj(JAPLException, ObjectTypes.EXCEPTION)
    result.errName = newString("RecursionError")
    result.message = newString(message)

