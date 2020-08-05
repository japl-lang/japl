import tokentype
import valueobject

# Token object

type
  Token* = ref object
    kind*: TokenType
    lexeme*: string
    literal*: Value
    line*: int
