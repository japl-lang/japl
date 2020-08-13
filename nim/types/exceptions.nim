import objecttype

type JAPLException* = ref object of Obj



func newTypeError*(message: string): JAPLException =
    result = JAPLException(kind: ObjectTypes.EXCEPTION, errName: Obj(kind: STRING, str: "TypeError"), message: Obj(kind: ObjectTypes.STRING, str: message))
