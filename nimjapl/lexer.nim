import tables
import meta/tokentype
import meta/tokenobject
import meta/exceptions
import meta/valueobject
import strformat
import system


const TOKENS = to_table({
              "(": TokenType.LP, ")": TokenType.RP,
              "{": TokenType.LB, "}": TokenType.RB,
              ".": TokenType.DOT, ",": TokenType.COMMA,
              "-": TokenType.MINUS, "+": TokenType.PLUS,
              ";": TokenType.SEMICOLON, "*": TokenType.STAR,
              ">": TokenType.GT, "<": TokenType.LT,
              "=": TokenType.EQ, "!": TokenType.NEG,
              "/": TokenType.SLASH, "%": TokenType.MOD})

const RESERVED = to_table({
                "or": TokenType.OR, "and": TokenType.AND,
                "class": TokenType.CLASS, "fun": TokenType.FUN,
                "if": TokenType.IF, "else": TokenType.ELSE,
                "for": TokenType.FOR, "while": TokenType.WHILE,
                "var": TokenType.VAR, "nil": TokenType.NIL,
                "true": TokenType.TRUE, "false": TokenType.FALSE,
                "return": TokenType.RETURN,
                "this": TokenType.THIS, "super": TokenType.SUPER,
                "del": TokenType.DEL, "break": TokenType.BREAK})


type Lexer* = object
  source: string
  tokens: seq[Token]
  line: int
  start: int
  current: int


proc initLexer*(source: string): Lexer =
  result = Lexer(source: source, tokens: @[], line: 1, start: 0, current: 0)


proc step*(self: var Lexer): char =
  result = self.source[self.current]
  self.current = self.current + 1


proc done*(self: Lexer): bool =
    result = self.current >= self.source.len


proc peek*(self: Lexer): string =
    if self.done():
        result = ""
    else:
        result = &"{self.source[self.current]}"


proc peekNext*(self: Lexer): string =
    if self.current + 1 >= self.source.len:
        result = ""
    else:
        result = &"{self.source[self.current + 1]}"


proc createToken*(self: var Lexer, tokenType: TokenType, literal: Value): Token =
    result = Token(kind: tokenType,
                   lexeme: self.source[self.start..<self.current],
                   literal: literal,
                   line: self.line
                   )


proc parseString*(self: var Lexer, delimiter: string) =
    while self.peek() != delimiter and not self.done():
        if self.peek() == "\n":
            self.line = self.line + 1
        discard self.step()
    if self.done():
        raise newException(ParseError, &"Unterminated string literal at {self.line}")
    discard self.step()
    let value = StrValue(value: self.source[self.start..<self.current - 1]) # Get the value between quotes
    let token = self.createToken(STR, value)
    self.tokens.add(token)


var lexer = initLexer("'hello'")
