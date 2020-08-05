import tokentype
# Token object

type
  Token*[T] = ref object of RootOBJ
    kind*: TokenType
    lexeme*: string
    literal*: T
    line*: int
