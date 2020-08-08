import lexer
import vm
import strformat
import meta/chunk
import meta/tokentype
import meta/tokenobject


type Compiler* = ref object

type Parser* = ref object
    current: int
    tokens: seq[Token]
    hadError: bool
    panicMode: bool

proc advance(self: var Parser): Token =
    inc(self.current)
    return self.tokens[self.current - 1]


proc peek(self: Parser): Token =
    return self.tokens[self.current]


proc previous(self: Parser): Token =
    return self.tokens[self.current - 1]


proc consume(self, expected: TokenType) =
    if self.peek().kind == expected:
        self.advance()
        return
    self.parseError(self.peek(), &"Found '{token.kind}' ('{token.lexeme}'), while parsing for {expected}")


proc parseError(self: var Parser, token: Token, message: string) =
    if self.panicMode:
        return
    self.panicMode = true
    echo &"ParseError at line {token.line}, at '{token.lexeme}' -> {message}"


proc initCompiler*(): Compiler =
    result = Compiler()


proc initParser(tokens: seq[Token]): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false)


proc compile*(self: Compiler, source: string, chunk: Chunk): bool
    var scanner = initLexer(source)
    var tokens = scanner.lex()
    var parser = initParser(tokens)
    parser.advance()
    parser.expression()
    parser.consume(EOF, "Expecting end of file")
    return not parser.hadError
