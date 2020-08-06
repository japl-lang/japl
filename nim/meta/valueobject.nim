# Value objects

type
  Value*[T] = ref object of RootObj
    value*: T
  StrValue* = ref object of Value
    value*: string
  CharValue* = ref object of Value
    value*: char
  IntValue* = ref object of Value
    value*: int
  FloatValue* = ref object of Value
    value*: float
