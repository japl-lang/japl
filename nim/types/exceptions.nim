import objecttype
import stringtype


type JAPLException* = ref object of Obj
    errName*: String
    message*: String


func newTypeError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("TypeError"), message: newString(message))


func newIndexError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("IndexError"), message: newString(message))


func newReferenceError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("ReferenceError"), message: newString(message))


func newInterruptedError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: newString("InterruptedError"), message: newString(message))


