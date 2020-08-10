import ../meta/valueobject


func newTypeError*(): Obj =
    result = Obj(kind: ObjectTypes.EXCEPTION, errName: Obj(kind: STRING, str: "TypeError"))

