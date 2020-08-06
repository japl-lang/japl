# The root of all JAPL objects
import ../meta/tokentype
import tables
import ../meta/tokenobject
import ../meta/valueobject

type Object* = ref object of RootObj
  value*: Value
  kind*: string
  operands*: table[TokenType, string]  # All supported operation on a given type


proc supportedBinaryOperand*(self: Object, operator: Token, other: Object): bool =
    if operator.kind not in self.operands:
        return false
    elif operator.kind not in other.operands:
        return false
    elif other.kind not in self.operands[operator.kind]:
        return false
    elif self.kind not in other.operands[operator.kind]:
        return false
    return true

