import lexer
import vm
import strformat
import meta/chunk
import meta/tokenobject
import meta/valueobject



type Compiler* = ref object
    compilingChunk: Chunk
    parser: Parser

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


proc compileError(self: Compiler, message: string):
    quit(message)


proc parseError(self: var Parser, token: Token, message: string) =
    if self.panicMode:
        return
    self.panicMode = true
    echo &"ParseError at line {token.line}, at '{token.lexeme}' -> {message}"


proc initParser(tokens: seq[Token]): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false)


proc initCompiler*(chunk: Chunk): Compiler =
    result = Compiler(parser: initParser(), compilingChunk: chunk)


proc emitByte(self: Compiler, byt: uint8) =
    self.compilingChunk.writeChunk(byt, self.parser.previous().line)


proc emitBytes(self: Compiler, byt1: uint8, byt2: uint8):
    self.emitByte(byt1)
    self.emitByte(byt2)


proc makeConstant(self: Compiler, val: Value): uint8
    result = uint8 self.compilingChunk.addConstant(value)
    if result > uint8.high:
        self.compileError("Too many constants in one chunk")


proc emitConstant(self: Compiler, value: Value):
    if self.compilingChunk.consts.len > 255:
        self.emitByte(OP_CONSTANT_LONG)
        var arr = self.compilingChunk.writeConstant(value)
        self.emitBytes(arr[0], arr[1])
        self.emitByte(arr[2])
    else:
        self.emitBytes(OP_CONSTANT, self.makeConstant(value))


proc endCompiler(self: Compiler) =
    self.emitByte(OP_RETURN)


proc number(self: compiler) =
    value = self.previous().literal
    self.emitConstant(value)


proc compile*(self: Compiler, source: string, chunk: Chunk): bool
    var scanner = initLexer(source)
    var tokens = scanner.lex()
    self.parser = initParser(tokens)
    self.compilingChunk = chunk
    parser.advance()
    parser.expression()
    parser.consume(EOF, "Expecting end of file")
    self.endCompiler()
    return not parser.hadError
