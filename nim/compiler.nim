import lexer
import strformat
import meta/chunk
import meta/tokenobject
import meta/valueobject
import meta/tokentype
import types/objecttype
import strutils
import strformat


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
    result = self.tokens[self.current]
    inc(self.current)


proc peek(self: Parser): Token =
    return self.tokens[self.current]


proc previous(self: Parser): Token =
    return self.tokens[self.current - 1]


proc check(self: Parser, kind: TokenType): bool =
    return self.peek().kind == kind


proc match(self: var Parser, kind: TokenType): bool =
    if not self.check(kind): return false
    discard self.advance()
    return true


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
proc statement(self: Compiler)
proc declaration(self: Compiler)


proc endCompiler(self: Compiler) =
    self.emitByte(OP_RETURN)


proc parsePrecedence(self: Compiler, precedence: Precedence) =
    discard self.parser.advance()
    var prefixRule = getRule(self.parser.previous.kind).prefix
    if prefixRule == nil:
        self.parser.parseError(self.parser.previous, "Expecting expression")
        return
    self.prefixRule()
    while precedence <= (getRule(self.parser.peek.kind).precedence):
        var infixRule = getRule(self.parser.advance.kind).infix
        if self.parser.peek.kind != EOF:
            self.infixRule()
        else:
            self.parser.parseError(self.parser.previous, "Expecting expression, got EOF")


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
        of MOD:
            self.emitByte(OP_MOD)
        of POW:
            self.emitByte(OP_POW)
        of NE:
            self.emitBytes(OP_EQUAL, OP_NOT)
        of DEQ:
            self.emitByte(OP_EQUAL)
        of GT:
            self.emitByte(OP_GREATER)
        of GE:
            self.emitBytes(OP_LESS, OP_NOT)
        of LT:
            self.emitByte(OP_LESS)
        of LE:
            self.emitBytes(OP_GREATER, OP_NOT)
        else:
            return


proc unary(self: Compiler) =
    var operator = self.parser.previous().kind
    if self.parser.peek().kind != EOF:
        self.parsePrecedence(PREC_UNARY)
    else:
        self.parser.parseError(self.parser.previous, "Expecting expression, got EOF")
        return
    case operator:
        of MINUS:
            self.emitByte(OP_NEGATE)
        of NEG:
            self.emitByte(OP_NOT)
        else:
            return


proc strVal(self: Compiler) =
    var str = self.parser.previous().lexeme
    var delimiter = &"{str[0]}"
    str = str.unescape(delimiter, delimiter)
    self.emitConstant(Value(kind: OBJECT, obj: Obj(kind: STRING, str: str)))


proc bracket(self: Compiler) =
    if self.parser.peek.kind == COLON:
        self.emitByte(OP_NIL)
        discard self.parser.advance()
        if self.parser.peek.kind == RS:
            self.emitByte(OP_NIL)
        else:
            self.parsePrecedence(PREC_TERM)
        self.emitByte(OP_SLICE_RANGE)
    else:
        self.parsePrecedence(PREC_TERM)
        if self.parser.peek.kind == RS:
            self.emitByte(OP_SLICE)
        elif self.parser.peek.kind == COLON:
            discard self.parser.advance()
            if self.parser.peek.kind == RS:
                self.emitByte(OP_NIL)
            else:
                self.parsePrecedence(PREC_TERM)
            self.emitByte(OP_SLICE_RANGE)
    self.parser.consume(TokenType.RS, "Expecting ']' after slice expression")


proc literal(self: Compiler) =
    case self.parser.previous().kind:
        of TRUE:
            self.emitByte(OP_TRUE)
        of FALSE:
            self.emitByte(OP_FALSE)
        of TokenType.NIL:
            self.emitByte(OP_NIL)
        else:
            discard  # Unreachable


proc number(self: Compiler) =
    var value = self.parser.previous().literal
    self.emitConstant(value)


proc grouping(self: Compiler) =
    self.expression()
    self.parser.consume(RP, "Expecting ')' after parentheszed expression")


proc synchronize(self: Compiler) =
    self.parser.panicMode = false
    while self.parser.peek.kind != EOF:
        if self.parser.previous().kind == SEMICOLON:
            return
        case self.parser.peek.kind:
            of CLASS, FUN, VAR, FOR, IF, WHILE, RETURN:
                return
            else:
                discard
        discard self.parser.advance()


proc identifierConstant(self: Compiler, tok: Token): uint8 =
    return self.makeConstant(Value(kind: OBJECT, obj: Obj(kind: STRING, str: tok.lexeme)))


proc parseVariable(self: Compiler, message: string): uint8 =
    self.parser.consume(ID, message)
    return self.identifierConstant(self.parser.previous)


proc defineVariable(self: Compiler, idx: uint8) =
    self.emitBytes(OP_DEFINE_GLOBAL, idx)


proc namedVariable(self: Compiler, tok: Token) =
    var name = self.identifierConstant(tok)
    if self.parser.match(EQ):
        self.expression()
        self.emitBytes(OP_SET_GLOBAL, name)
    else:
        self.emitBytes(OP_GET_GLOBAL, name)


proc variable(self: Compiler) =
    self.namedVariable(self.parser.previous())


proc varDeclaration(self: Compiler) =
    var name = self.parseVariable("Expecting variable name")
    if self.parser.match(EQ):
        self.expression()
    else:
        self.emitByte(OP_NIL)
    self.parser.consume(SEMICOLON, "Missing semicolon after var declaration")
    self.defineVariable(name)


proc expressionStatement(self: Compiler) =
    self.expression()
    self.parser.consume(SEMICOLON, "Missing semicolon after expression")
    self.emitByte(OP_POP)


proc statement(self: Compiler) =
    self.expressionStatement()


proc declaration(self: Compiler) =
    if self.parser.match(VAR):
        self.varDeclaration()
    else:
        self.statement()
    if self.parser.panicMode:
        self.synchronize()


var rules: array[TokenType, ParseRule] = [
    makeRule(nil, binary, PREC_TERM), # PLUS
    makeRule(unary, binary, PREC_TERM), # MINUS
    makeRule(nil, binary, PREC_FACTOR), # SLASH
    makeRule(nil, binary, PREC_FACTOR), # STAR
    makeRule(unary, nil, PREC_NONE), # NEG
    makeRule(nil, binary, PREC_EQUALITY), # NE
    makeRule(nil, nil, PREC_NONE), # EQ
    makeRule(nil, binary, PREC_COMPARISON), # DEQ
    makeRule(nil, binary, PREC_COMPARISON), # LT
    makeRule(nil, binary, PREC_COMPARISON), # GE
    makeRule(nil, binary, PREC_COMPARISON), # LE
    makeRule(nil, binary, PREC_FACTOR), # MOD
    makeRule(nil, binary, PREC_FACTOR), # POW
    makeRule(nil, binary, PREC_COMPARISON), # GT
    makeRule(grouping, nil, PREC_NONE), # LP
    makeRule(nil, nil, PREC_NONE), # RP
    makeRule(nil, bracket, PREC_CALL), # LS
    makeRule(nil, nil, PREC_NONE), # LB
    makeRule(nil, nil, PREC_NONE), # RB
    makeRule(nil, nil, PREC_NONE), # COMMA
    makeRule(nil, nil, PREC_NONE), # DOT
    makeRule(variable, nil, PREC_NONE), # ID
    makeRule(nil, nil, PREC_NONE), # RS
    makeRule(number, nil, PREC_NONE), # NUMBER
    makeRule(strVal, nil, PREC_NONE), # STR
    makeRule(nil, nil, PREC_NONE), # SEMICOLON
    makeRule(nil, nil, PREC_NONE), # AND
    makeRule(nil, nil, PREC_NONE), # CLASS
    makeRule(nil, nil, PREC_NONE), # ELSE
    makeRule(nil, nil, PREC_NONE), # FOR
    makeRule(nil, nil, PREC_NONE), # FUN
    makeRule(literal, nil, PREC_NONE), # FALSE
    makeRule(nil, nil, PREC_NONE), # IF
    makeRule(literal, nil, PREC_NONE), # NIL
    makeRule(nil, nil, PREC_NONE), # RETURN
    makeRule(nil, nil, PREC_NONE), # SUPER
    makeRule(nil, nil, PREC_NONE), # THIS
    makeRule(nil, nil, PREC_NONE), # OR
    makeRule(literal, nil, PREC_NONE), # TRUE
    makeRule(nil, nil, PREC_NONE), # VAR
    makeRule(nil, nil, PREC_NONE), # WHILE
    makeRule(nil, nil, PREC_NONE), # DEL
    makeRule(nil, nil, PREC_NONE), # BREAK
    makeRule(nil, nil, PREC_NONE), # EOF
    makeRule(nil, nil, PREC_NONE), # COLON
]


proc getRule(kind: TokenType): ParseRule =
    result = rules[kind]


proc compile*(self: var Compiler, source: string, chunk: Chunk): bool =
    var scanner = initLexer(source)
    var tokens = scanner.lex()
    if len(tokens) > 1 and not scanner.errored:
        self.parser = initParser(tokens)
        self.compilingChunk = chunk
        while not self.parser.match(EOF):
            self.declaration()
        self.endCompiler()
    return not self.parser.hadError
