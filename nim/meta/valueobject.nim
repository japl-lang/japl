# Value objects

type
  Value* = ref object of RootObj
  StrValue* = ref object of Value
    value*: string
  IntValue* = ref object of Value
    value*: int
  FloatValue* = ref object of Value
    value*: float


proc `$`(obj: StrValue): string =
    result = obj.value


proc `$`(obj: IntValue): string =
    result = $obj.value


proc `$`(obj: FloatValue): string =
    result = $obj.value
