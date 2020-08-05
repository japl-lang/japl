# Value objects

type
  Value* = ref object of RootObj
  StrValue* = ref object of Value
    value*: string
  IntValue* = ref object of Value
    value*: int
  FloatValue* = ref object of Value
    value*: float
