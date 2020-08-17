import tables
import meta/tokentype
import meta/tokenobject
import meta/valueobject
import types/objecttype
import system
import strutils
import strformat


const TOKENS = to_table({
              '(': TokenType.LP, ')': TokenType.RP,
              '{': TokenType.LB, '}': TokenType.RB,
              '.': TokenType.DOT, ',': TokenType.COMMA,
              '-': TokenType.MINUS, '+': TokenType.PLUS,
              ';': TokenType.SEMICOLON, '*': TokenType.STAR,
              '>': TokenType.GT, '<': TokenType.LT,
              '=': TokenType.EQ, '!': TokenType.NEG,
              '/': TokenType.SLASH, '%': TokenType.MOD,
              '[': TokenType.LS, ']': TokenType.RS,
              ':': TokenType.COLON})

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
  errored*: bool


proc initLexer*(source: string): Lexer =
  result = Lexer(source: source, tokens: @[], line: 1, start: 0, current: 0, errored: false)


proc done(self: Lexer): bool =
    result = self.current >= self.source.len


proc step(self: var Lexer): char =
    if self.done():
        return '\0'
    self.current = self.current + 1
    result = self.source[self.current - 1]


proc peek(self: Lexer): char =
    if self.done():
        result = '\0'
    else:
        result = self.source[self.current]


proc match(self: var Lexer, what: char): bool =
    if self.done():
        return false
    elif self.peek() != what:
        return false
    self.current = self.current + 1
    return true


proc peekNext(self: Lexer): char =
    if self.current + 1 >= self.source.len:
        result = '\0'
    else:
        result = self.source[self.current + 1]


proc createToken(self: var Lexer, tokenType: TokenType, literal: Value): Token =
    result = Token(kind: tokenType,
                   lexeme: self.source[self.start..<self.current],
                   literal: literal,
                   line: self.line
                   )


proc parseString(self: var Lexer, delimiter: char) =
    while self.peek() != delimiter and not self.done():
        if self.peek() == '\n':
            self.line = self.line + 1
        discard self.step()
    if self.done():
        echo &"SyntaxError: Unterminated string literal at line {self.line}"
        self.errored = true
    discard self.step()
    let value = Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: self.source[self.start..<self.current])) # Get the value between quotes
    let token = self.createToken(STR, value)
    self.tokens.add(token)


proc parseNumber(self: var Lexer) =
    while isDigit(self.peek()):
        discard self.step()
    if self.peek() == '.':
        discard self.step()
        while self.peek().isDigit():
            discard self.step()
        var value = Value(kind: ValueTypes.DOUBLE, floatValue: parseFloat(self.source[self.start..<self.current]))
        self.tokens.add(self.createToken(TokenType.NUMBER, value))
    else:
        var value = Value(kind: ValueTypes.INTEGER, intValue: parseInt(self.source[self.start..<self.current]))
        self.tokens.add(self.createToken(TokenType.NUMBER, value))


proc parseIdentifier(self: var Lexer) =
    while self.peek().isAlphaNumeric():
        discard self.step()
    var text: string = self.source[self.start..<self.current]
    var keyword = text in RESERVED
    if keyword:
        self.tokens.add(self.createToken(RESERVED[text], Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: text))))
    else:
        self.tokens.add(self.createToken(ID, Value(kind: ValueTypes.OBJECT, obj: Obj(kind:ObjectTypes.STRING, str: text))))


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
        self.errored = true
        echo &"SyntaxError: Unexpected EOF at line {self.line}"


proc scanToken(self: var Lexer) =
    var single = self.step()
    if single in [' ', '\t', '\r']:
        return
    elif single == '\n':
        self.current = self.current + 1
    elif single in ['"', '\'']:
        self.parseString(single)
    elif single.isDigit():
        self.parseNumber()
    elif single.isAlphaNumeric() or single == '_':
        self.parseIdentifier()
    elif single in TOKENS:
        if single == '/' and self.match('/'):
            while self.peek() != '\n' and not self.done():
                discard self.step()
        elif single == '/' and self.match('*'):
            self.parseComment()
        elif single == '=' and self.match('='):
            self.tokens.add(self.createToken(DEQ, Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: "=="))))
        elif single == '>' and self.match('='):
            self.tokens.add(self.createToken(GE, Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: ">="))))
        elif single == '<' and self.match('='):
            self.tokens.add(self.createToken(LE, Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: "<="))))
        elif single == '!' and self.match('='):
            self.tokens.add(self.createToken(NE, Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: "!="))))
        elif single == '*' and self.match('*'):
            self.tokens.add(self.createToken(POW, Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: "**"))))
        else:
            self.tokens.add(self.createToken(TOKENS[single], Value(kind: ValueTypes.OBJECT, obj: Obj(kind: ObjectTypes.STRING, str: &"{single}"))))
    else:
        self.errored = true
        echo &"SyntaxError: Unexpected character '{single}' at {self.line}"


proc lex*(self: var Lexer): seq[Token] =
    while not self.done():
        self.start = self.current
        self.scanToken()
    self.tokens.add(Token(kind: EOF, lexeme: "EOF", literal: Value(kind: ValueTypes.NIL), line: self.line))
    return self.tokens

