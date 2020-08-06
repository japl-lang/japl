import tables
import meta/tokentype
import meta/tokenobject
import meta/exceptions
import meta/valueobject
import system
import strutils
import strformat


const TOKENS = to_table({
              "(": TokenType.LP, ")": TokenType.RP,
              "{": TokenType.LB, "}": TokenType.RB,
              ".": TokenType.DOT, ",": TokenType.COMMA,
              "-": TokenType.MINUS, "+": TokenType.PLUS,
              ";": TokenType.SEMICOLON, "*": TokenType.STAR,
              ">": TokenType.GT, "<": TokenType.LT,
              "=": TokenType.EQ, "!": TokenType.NEG,
              "/": TokenType.SLASH, "%": TokenType.MOD,
               "[": TokenType.LS, "]": TokenType.RS})

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


proc done(self: Lexer): bool =
    result = self.current >= self.source.len


proc step(self: var Lexer): string =
    if self.done():
        return ""
    self.current = self.current + 1
    result = &"{self.source[self.current - 1]}"


proc peek(self: Lexer): string =
    if self.done():
        result = ""
    else:
        result = &"{self.source[self.current]}"


proc match(self: var Lexer, what: string): bool =
    if self.done():
        return false
    elif self.peek() != what:
        return false
    self.current = self.current + 1
    return true


proc peekNext(self: Lexer): string =
    if self.current + 1 >= self.source.len:
        result = ""
    else:
        result = &"{self.source[self.current + 1]}"


proc isDigit(s: string): bool =
    result = s >= "0" and s <= "9"


proc isAlpha(s: string): bool =
    result = (s >= "a" and s <= "z") or (s >= "A" and s <= "Z") or s == "_"


proc isAlnum(s: string): bool =
    result = isDigit(s) or isAlpha(s)


proc createToken(self: var Lexer, tokenType: TokenType, literal: Value): Token =
    result = Token(kind: tokenType,
                   lexeme: self.source[self.start..<self.current],
                   literal: literal,
                   line: self.line
                   )


proc parseString(self: var Lexer, delimiter: string) =
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


proc parseNumber(self: var Lexer) =
    while isDigit(self.peek()):
        discard self.step()
    if self.peek() == ".":
        discard self.step()
        while self.peek().isDigit():
            discard self.step()
        var value = FloatValue(value: parseFloat(self.source[self.start..<self.current]))
        self.tokens.add(self.createToken(FLOAT, value))
    else:
        var value = IntValue(value: parseInt(self.source[self.start..<self.current]))
        self.tokens.add(self.createToken(INT, value))


proc parseIdentifier(self: var Lexer) =
    while isAlnum(self.peek()):
        discard self.step()
    var text: string = self.source[self.start..<self.current]
    var keyword = text in RESERVED
    if keyword:
        self.tokens.add(self.createToken(RESERVED[text], StrValue(value: text)))
    else:
        self.tokens.add(self.createToken(ID, StrValue(value: text)))


proc parseComment(self: var Lexer) =
    var closed = false
    while not self.done():
        var finish = self.peek() & self.peekNext()
        if finish == "/*":   # Nested comments
            discard self.step()
            discard self.step()
            self.parseComment()
        elif finish == "*/":
            closed = true
            discard self.step()   # Consume the two ends
            discard self.step()
            break
        discard self.step()
    if self.done() and not closed:
        raise newException(ParseError, &"Unexpected EOF at line {self.line}")


proc scanToken(self: var Lexer) =
    var single = self.step()
    if single in [" ", "\t", "\r"]:
        return
    elif single == "\n":
        self.current = self.current + 1
    elif single in ["""'""", "'"]:
        self.parseString(single)
    elif single.isDigit():
        self.parseNumber()
    elif single.isAlnum():
        self.parseIdentifier()
    elif single in TOKENS:
        if single == "/" and self.match("/"):
            while self.peek() != "\n" and not self.done():
                discard self.step()
        elif single == "/" and self.match("*"):
            self.parseComment()
        elif single == "=" and self.match("="):
            self.tokens.add(self.createToken(DEQ, StrValue(value: "==")))
        elif single == ">" and self.match("="):
            self.tokens.add(self.createToken(GE, StrValue(value: ">=")))
        elif single == "<" and self.match("="):
            self.tokens.add(self.createToken(LE, StrValue(value: "<=")))
        elif single == "!" and self.match("="):
            self.tokens.add(self.createToken(NE, StrValue(value: "!=")))
        elif single == "*" and self.match("*"):
            self.tokens.add(self.createToken(POW, StrValue(value: "**")))
        else:
            self.tokens.add(self.createToken(TOKENS[single], StrValue(value: single)))
    else:
        raise newException(ParseError, &"Unexpected character '{single}' at {self.line}")


proc lex*(self: var Lexer): seq[Token] =
    while not self.done():
        self.start = self.current
        self.scanToken()
    self.tokens.add(Token(kind: EOF, lexeme: "", literal: IntValue(value: -1), line: self.line))
    return self.tokens
