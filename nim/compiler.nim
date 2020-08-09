import lexer
import vm
import strformat
import meta/chunk
import meta/tokenobject
import meta/valueobject
import meta/tokentype



type
    Compiler = ref object
        compilingChunk: Chunk
        parser: Parser

    Parser = ref object
        current: int
        tokens: seq[Token]
        hadError: bool
        panicMode: bool

    Precedence = enum
        PREC_NONE,
        PREC_ASSIGNMENT,
        PREC_OR,
        PREC_AND,
        PREC_EQUALITY,
        PREC_COMPARISON,
        PREC_TERM,
        PREC_FACTOR,
        PREC_UNARY,
        PREC_CALL,
        PREC_PRIMARY

    ParseFn = proc(self: Compiler): void

    ParseRule = ref object
        prefix, infix: ParseFn
        precedence: Precedence


proc makeRule(prefix, infix: ParseFn, precedence: Precedence): ParseRule =
    return ParseRule(prefix: prefix, infix: infix, precedence: precedence)


proc advance(self: var Parser): Token =
    inc(self.current)
    return self.tokens[self.current - 1]


proc peek(self: Parser): Token =
    return self.tokens[self.current]


proc previous(self: Parser): Token =
    return self.tokens[self.current - 1]


proc parseError(self: var Parser, token: Token, message: string) =
    if self.panicMode:
        return
    self.panicMode = true
    self.hadError = true
    echo &"ParseError at line {token.line}, at '{token.lexeme}' -> {message}"


proc consume(self: var Parser, expected: TokenType, message: string) =
    if self.peek().kind == expected:
        discard self.advance()
        return
    self.parseError(self.peek(), message)


proc compileError(self: Compiler, message: string) =
    echo &"CompileError at line {self.parser.peek().line}: {message}"
    quit()


proc initParser(tokens: seq[Token]): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false)


proc initCompiler*(chunk: Chunk): Compiler =
    result = Compiler(parser: initParser(@[]), compilingChunk: chunk)


proc emitByte(self: Compiler, byt: OpCode|uint8) =
    self.compilingChunk.writeChunk(uint8 byt, self.parser.previous().line)


proc emitBytes(self: Compiler, byt1: OpCode|uint8, byt2: OpCode|uint8) =
    self.emitByte(uint8 byt1)
    self.emitByte(uint8 byt2)


proc makeConstant(self: Compiler, val: Value): uint8 =
    result = uint8 self.compilingChunk.addConstant(val)
    if result > uint8.high:
        self.compileError("Too many constants in one chunk")


proc emitConstant(self: Compiler, value: Value) =
    if self.compilingChunk.consts.values.len > 255:
        self.emitByte(OP_CONSTANT_LONG)
        var arr = self.compilingChunk.writeConstant(value)
        self.emitBytes(arr[0], arr[1])
        self.emitByte(arr[2])
    else:
        self.emitBytes(OP_CONSTANT, self.makeConstant(value))

proc getRule(kind: TokenType): ParseRule  # Forward declaration


proc endCompiler(self: Compiler) =
    self.emitByte(OP_RETURN)


proc parsePrecedence(self: Compiler, precedence: Precedence) =
    return


proc expression(self: Compiler) =
    self.parsePrecedence(PREC_ASSIGNMENT)


proc binary(self: Compiler) =
    var operator = self.parser.previous.kind
    var rule = getRule(operator)
    self.parsePrecedence(Precedence((int rule.precedence) + 1))
    case operator:
        of PLUS:
            self.emitByte(OP_ADD)
        of MINUS:
            self.emitByte(OP_SUBTRACT)
        of SLASH:
            self.emitByte(OP_DIVIDE)
        of STAR:
            self.emitByte(OP_MULTIPLY)
        else:
            return

proc unary(self: Compiler) =
    var operator = self.parser.previous().kind
    self.parsePrecedence(PREC_UNARY)
    case operator:
        of MINUS:
            self.emitByte(OP_NEGATE)
        else:
            return

proc str(self: Compiler) =
    return


proc literal(self: Compiler) =
    return


proc number(self: Compiler) =
    var value = self.parser.previous().literal
    self.emitConstant(value)


proc grouping(self: Compiler) =
    self.expression()
    self.parser.consume(RP, "Expecting ')' after parenthesized expression")


var rules: array[39, ParseRule] = [
  makeRule(grouping, nil, PREC_NONE), # LP
  makeRule(nil, nil, PREC_NONE), # RP
  makeRule(nil, nil, PREC_NONE), # LB
  makeRule(nil, nil, PREC_NONE), # RB
  makeRule(nil, nil, PREC_NONE), # COMMA
  makeRule(nil, nil, PREC_NONE), # DOT
  makeRule(unary, binary, PREC_TERM), # MINUS
  makeRule(nil, binary, PREC_TERM), # PLUS
  makeRule(nil, nil, PREC_NONE), # SEMICOLON
  makeRule(nil, binary, PREC_FACTOR), # SLASH
  makeRule(nil, binary, PREC_FACTOR), # STAR
  makeRule(unary, nil, PREC_NONE), # NEG
  makeRule(nil, binary, PREC_EQUALITY), # NE
  makeRule(nil, nil, PREC_NONE), # EQ
  makeRule(nil, binary, PREC_COMPARISON), # DEQ
  makeRule(nil, binary, PREC_COMPARISON), # GT
  makeRule(nil, binary, PREC_COMPARISON), # GE
  makeRule(nil, binary, PREC_COMPARISON), # LT
  makeRule(nil, binary, PREC_COMPARISON), # LE
  makeRule(nil, nil, PREC_NONE), # ID
  makeRule(str, nil, PREC_NONE), # STR
  makeRule(number, nil, PREC_NONE), # INT
  makeRule(number, nil, PREC_NONE), # FLOAT
  makeRule(nil, nil, PREC_NONE), # AND
  makeRule(nil, nil, PREC_NONE), # CLASS
  makeRule(nil, nil, PREC_NONE), # ELSE
  makeRule(literal, nil, PREC_NONE), # FALSE
  makeRule(nil, nil, PREC_NONE), # FOR
  makeRule(nil, nil, PREC_NONE), # FUN
  makeRule(nil, nil, PREC_NONE), # IF
  makeRule(literal, nil, PREC_NONE), # NIL
  makeRule(nil, nil, PREC_NONE), # OR
  makeRule(nil, nil, PREC_NONE), # RETURN
  makeRule(nil, nil, PREC_NONE), # SUPER
  makeRule(nil, nil, PREC_NONE), # THIS
  makeRule(literal, nil, PREC_NONE), # TRUE
  makeRule(nil, nil, PREC_NONE), # VAR
  makeRule(nil, nil, PREC_NONE), # WHILE
  makeRule(nil, nil, PREC_NONE), # EOF
]


proc getRule(kind: TokenType): ParseRule =
  return rules[int kind]


proc compile*(self: Compiler, source: string, chunk: Chunk): bool =
    var scanner = initLexer(source)
    var tokens = scanner.lex()
    self.parser = initParser(tokens)
    self.compilingChunk = chunk
    discard self.parser.advance()
    self.expression()
    self.parser.consume(EOF, "Expecting end of file")
    self.endCompiler()
    return not self.parser.hadError
