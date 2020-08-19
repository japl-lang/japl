import strutils
import algorithm
import strformat
import lexer
import meta/chunk
import meta/tokenobject
import meta/valueobject
import meta/tokentype
import types/objecttype
import meta/looptype


type
    Local = ref object
       name: Token
       depth: int

    Compiler = ref object
        locals: seq[Local]
        localCount: int
        scopeDepth: int
        compilingChunk: Chunk
        parser*: Parser
        loopType: LoopType

    Parser = ref object
        current: int
        tokens: seq[Token]
        hadError*: bool
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

    ParseFn = proc(self: Compiler, canAssign: bool): void

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
    self.parser.hadError = true


proc initParser(tokens: seq[Token]): Parser =
    result = Parser(current: 0, tokens: tokens, hadError: false, panicMode: false)


proc initCompiler*(chunk: Chunk): Compiler =
    result = Compiler(parser: initParser(@[]), compilingChunk: chunk, locals: @[], scopeDepth: 0, localCount: 0, loopType: looptype.NONE)


proc emitByte(self: Compiler, byt: OpCode|uint8) =
    self.compilingChunk.writeChunk(uint8 byt, self.parser.previous().line)


proc emitBytes(self: Compiler, byt1: OpCode|uint8, byt2: OpCode|uint8) =
    self.emitByte(uint8 byt1)
    self.emitByte(uint8 byt2)


proc emitBytes(self: Compiler, bytarr: array[3, uint8]) =
    self.emitBytes(bytarr[0], bytarr[1])
    self.emitByte(bytarr[2])


proc makeConstant(self: Compiler, val: Value): uint8 =
    result = uint8 self.compilingChunk.addConstant(val)


proc makeLongConstant(self: Compiler, val: Value): array[3, uint8] =
    result = self.compilingChunk.writeConstant(val)


proc emitConstant(self: Compiler, value: Value) =
    if self.compilingChunk.consts.values.len > 255:
        self.emitByte(OP_CONSTANT_LONG)
        self.emitBytes(self.makeLongConstant(value))
    else:
        self.emitBytes(OP_CONSTANT, self.makeConstant(value))


proc getRule(kind: TokenType): ParseRule  # Forward declarations
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
    var canAssign = precedence <= PREC_ASSIGNMENT
    self.prefixRule(canAssign)
    if self.parser.previous.kind == EOF:
        self.parser.current -= 1
        return
    while precedence <= (getRule(self.parser.peek.kind).precedence):
        var infixRule = getRule(self.parser.advance.kind).infix
        if self.parser.peek.kind != EOF:
            self.infixRule(canAssign)
        else:
            self.parser.parseError(self.parser.previous, "Expecting expression, got EOF")
    if canAssign and self.parser.match(EQ):
        self.parser.parseError(self.parser.peek, "Invalid assignment target")


proc expression(self: Compiler) =
    self.parsePrecedence(PREC_ASSIGNMENT)


proc binary(self: Compiler, canAssign: bool) =
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


proc unary(self: Compiler, canAssign: bool) =
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


proc strVal(self: Compiler, canAssign: bool) =
    var str = self.parser.previous().lexeme
    var delimiter = &"{str[0]}"
    str = str.unescape(delimiter, delimiter)
    self.emitConstant(Value(kind: OBJECT, obj: Obj(kind: STRING, str: str)))


proc bracket(self: Compiler, canAssign: bool) =
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


proc literal(self: Compiler, canAssign: bool) =
    case self.parser.previous().kind:
        of TRUE:
            self.emitByte(OP_TRUE)
        of FALSE:
            self.emitByte(OP_FALSE)
        of TokenType.NIL:
            self.emitByte(OP_NIL)
        else:
            discard  # Unreachable


proc number(self: Compiler, canAssign: bool) =
    var value = self.parser.previous().literal
    self.emitConstant(value)


proc grouping(self: Compiler, canAssign: bool) =
    if self.parser.match(EOF):
        self.parser.parseError(self.parser.previous, "Expecting ')'")
    elif self.parser.match(RP):
        self.emitByte(OP_NIL)
    else:
        self.expression()
        self.parser.consume(RP, "Expecting ')' after parentheszed expression")


proc synchronize(self: Compiler) =
    self.parser.panicMode = false
    while self.parser.peek.kind != EOF:
        if self.parser.previous().kind == SEMICOLON:
            return
        case self.parser.peek.kind:
            of CLASS, FUN, VAR, TokenType.FOR, IF, TokenType.WHILE, RETURN:
                return
            else:
                discard
        discard self.parser.advance()


proc identifierConstant(self: Compiler, tok: Token): uint8 =
    return self.makeConstant(Value(kind: OBJECT, obj: Obj(kind: STRING, str: tok.lexeme)))


proc identifierLongConstant(self: Compiler, tok: Token): array[3, uint8] =
    return self.makeLongConstant(Value(kind: OBJECT, obj: Obj(kind: STRING, str: tok.lexeme)))


proc addLocal(self: Compiler, name: Token) =
    var local = Local(name: name, depth: self.scopeDepth)
    inc(self.localCount)
    self.locals.add(local)


proc declareVariable(self: Compiler) =
    if self.scopeDepth == 0:
        return
    var name = self.parser.previous()
    self.addLocal(name)


proc parseVariable(self: Compiler, message: string): uint8 =
    self.parser.consume(ID, message)
    self.declareVariable()
    if self.scopeDepth > 0:
        return uint8 0
    return self.identifierConstant(self.parser.previous)


proc parseLongVariable(self: Compiler, message: string): array[3, uint8] =
    self.parser.consume(ID, message)
    self.declareVariable()
    if self.scopeDepth > 0:
        return [uint8 0, uint8 0, uint8 0]
    return self.identifierLongConstant(self.parser.previous)


proc defineVariable(self: Compiler, idx: uint8) =
    if self.scopeDepth > 0:
        return
    self.emitBytes(OP_DEFINE_GLOBAL, idx)


proc defineVariable(self: Compiler, idx: array[3, uint8]) =
    if self.scopeDepth > 0:
        return
    self.emitByte(OP_DEFINE_GLOBAL)
    self.emitBytes(idx)


proc resolveLocal(self: Compiler, name: Token): int =
    var i = self.localCount - 1
    for local in reversed(self.locals):
        if local.name.lexeme == name.lexeme:
            return i
        i = i - 1
    return -1


proc namedVariable(self: Compiler, tok: Token, canAssign: bool) =
    var arg = self.resolveLocal(tok)
    var
        get: OpCode
        set: OpCode
    if arg != -1:
        get = OP_GET_LOCAL
        set = OP_SET_LOCAL
    else:
        get = OP_GET_GLOBAL
        set = OP_SET_GLOBAL
        arg = int self.identifierConstant(tok)
    if self.parser.match(EQ) and canAssign:
        self.expression()
        self.emitBytes(set, uint8 arg)
    else:
        self.emitBytes(get, uint8 arg)


proc namedLongVariable(self: Compiler, tok: Token, canAssign: bool) =
    var arg = self.resolveLocal(tok)
    var casted = cast[array[3, uint8]](arg)
    var
        get: OpCode
        set: OpCode
    if arg != -1:
        get = OP_GET_LOCAL
        set = OP_SET_LOCAL
    else:
        get = OP_GET_GLOBAL
        set = OP_SET_GLOBAL
        casted = self.identifierLongConstant(tok)
    if self.parser.match(EQ) and canAssign:
        self.expression()
        self.emitByte(set)
        self.emitBytes(casted)
    else:
        self.emitByte(get)
        self.emitBytes(casted)



proc variable(self: Compiler, canAssign: bool) =
    if self.locals.len < 255:
        self.namedVariable(self.parser.previous(), canAssign)
    else:
        self.namedLongVariable(self.parser.previous(), canAssign)


proc varDeclaration(self: Compiler) =
    var shortName: uint8
    var longName: array[3, uint8]
    var useShort: bool = true
    if self.compilingChunk.consts.values.len < 255:
        shortName = self.parseVariable("Expecting variable name")
    else:
        useShort = false
        longName = self.parseLongVariable("Expecting variable name")
    if self.parser.match(EQ):
        self.expression()
    else:
        self.emitByte(OP_NIL)
    self.parser.consume(SEMICOLON, "Missing semicolon after var declaration")
    if useShort:
        self.defineVariable(shortName)
    else:
        self.defineVariable(longName)


proc expressionStatement(self: Compiler) =
    self.expression()
    self.parser.consume(SEMICOLON, "Missing semicolon after expression")
    self.emitByte(OP_POP)


proc deleteVariable(self: Compiler, canAssign: bool) =
    self.expression()
    if self.parser.previous().kind in [NUMBER, STR]:
        self.compileError("cannot delete a literal")
    var code: OpCode
    if self.scopeDepth == 0:
        code = OP_DELETE_GLOBAL
    else:
        code = OP_DELETE_LOCAL
    self.localCount = self.localCount - 1
    if self.compilingChunk.consts.values.len < 255:
        var name = self.identifierConstant(self.parser.previous())
        self.locals.delete(name)
        self.emitBytes(code, name)
    else:
        var name = self.identifierLongConstant(self.parser.previous())
        self.emitBytes(code, name[0])
        self.emitBytes(name[1], name[2])


proc parseBlock(self: Compiler) =
    while not self.parser.check(RB) and not self.parser.check(EOF):
        self.declaration()
    self.parser.consume(RB, "Expecting '}' after block statement")


proc beginScope(self: Compiler) =
    inc(self.scopeDepth)


proc endScope(self: Compiler) =
    self.scopeDepth = self.scopeDepth - 1
    while self.localCount > 0 and self.locals[self.localCount - 1].depth > self.scopeDepth:
        self.emitByte(OP_POP)
        self.localCount = self.localCount - 1


proc emitJump(self: Compiler, opcode: OpCode): int =
    self.emitByte(opcode)
    self.emitByte(0xff)
    self.emitByte(0xff)
    return self.compilingChunk.code.len - 2


proc patchJump(self: Compiler, offset: int) =
    var jump = self.compilingChunk.code.len - offset - 2
    if jump > (int uint16.high):
        self.compileError("too much code to jump over")
    else:
        self.compilingChunk.code[offset] = uint8 (jump shr 8) and 0xff
        self.compilingChunk.code[offset + 1] = uint8 jump and 0xff


proc ifStatement(self: Compiler) =
    self.parser.consume(LP, "The if condition must be parenthesized")
    if self.parser.peek.kind != EOF:
        self.expression()
        if self.parser.peek.kind != EOF:
            self.parser.consume(RP, "The if condition must be parenthesized")
        if self.parser.peek.kind != EOF:
            var jump: int = self.emitJump(OP_JUMP_IF_FALSE)
            self.emitByte(OP_POP)
            self.statement()
            var elseJump = self.emitJump(OP_JUMP)
            self.patchJump(jump)
            self.emitByte(OP_POP)
            if self.parser.match(ELSE):
                self.statement()
            self.patchJump(elseJump)
        else:
            self.parser.parseError(self.parser.previous, "Invalid syntax")
    else:
        self.parser.parseError(self.parser.previous, "The if condition must be parenthesized")


proc emitLoop(self: Compiler, start: int) =
    self.emitByte(OP_LOOP)
    var offset = self.compilingChunk.code.len - start + 2
    if offset > (int uint16.high):
        self.compileError("loop body is too large")
    else:
        self.emitByte(uint8 (offset shr 8) and 0xff)
        self.emitByte(uint8 offset and 0xff)


proc whileStatement(self: Compiler) =
    var loopStart = self.compilingChunk.code.len
    self.loopType = LoopType.WHILE
    self.parser.consume(LP, "The loop condition must be parenthesized")
    if self.parser.peek.kind != EOF:
        self.expression()
        if self.parser.peek.kind != EOF:
            self.parser.consume(RP, "The loop condition must be parenthesized")
        if self.parser.peek.kind != EOF:
            var exitJump = self.emitJump(OP_JUMP_IF_FALSE)
            self.emitByte(OP_POP)
            self.statement()
            self.emitLoop(loopStart)
            self.patchJump(exitJump)
            self.emitByte(OP_POP)
        else:
            self.parser.parseError(self.parser.previous, "Invalid syntax")
    else:
        self.parser.parseError(self.parser.previous, "The loop condition must be parenthesized")
    self.loopType = NONE


proc forStatement(self: Compiler) =
    self.beginScope()
    self.parser.consume(LP, "The loop condition must be parenthesized")
    self.loopType = LoopType.FOR
    if self.parser.peek.kind != EOF:
        if self.parser.match(SEMICOLON):
            discard
        elif self.parser.match(VAR):
            self.varDeclaration()
        else:
            self.expressionStatement()
        var loopStart = self.compilingChunk.code.len
        var exitJump = -1
        if not self.parser.match(SEMICOLON):
            self.expression()
            if self.parser.previous.kind != EOF:
                self.parser.consume(SEMICOLON, "Expecting ';'")
                exitJump = self.emitJump(OP_JUMP_IF_FALSE)
                self.emitByte(OP_POP)
            else:
                self.parser.current -= 1
                self.parser.parseError(self.parser.previous, "Invalid syntax")
        if not self.parser.match(RP):
            var bodyJump = self.emitJump(OP_JUMP)
            var incrementStart = self.compilingChunk.code.len
            if self.parser.peek.kind != EOF:
                self.expression()
                self.emitByte(OP_POP)
                self.parser.consume(RP, "The loop condition must be parenthesized")
                self.emitLoop(loopStart)
                loopStart = incrementStart
                self.patchJump(bodyJump)
        if self.parser.peek.kind != EOF:
            self.statement()
            self.emitLoop(loopStart)
        else:
            self.parser.current -= 1
            self.parser.parseError(self.parser.previous, "Invalid syntax")
        if exitJump != -1:
            self.patchJump(exitJump)
            self.emitByte(OP_POP)
        self.endScope()
    else:
        self.parser.parseError(self.parser.previous, "The loop condition must be parenthesized")
    self.loopType = NONE


proc parseBreak(self: Compiler) =
    if self.loopType == NONE:
        self.parser.parseError(self.parser.previous, "'break' outside loop")
    else:
        self.parser.consume(SEMICOLON, "missing semicolon after statement")
        var jmp = self.emitJump(OP_JUMP)
        if self.parser.peek.kind != EOF:
            self.declaration()
            self.emitByte(OP_POP)
        else:
            self.emitByte(OP_RETURN)
        self.patchJump(jmp)


proc parseAnd(self: Compiler, canAssign: bool) =
    var jump = self.emitJump(OP_JUMP_IF_FALSE)
    self.emitByte(OP_POP)
    self.parsePrecedence(PREC_AND)
    self.patchJump(jump)


proc parseOr(self: Compiler, canAssign: bool) =
    var elseJump = self.emitJump(OP_JUMP_IF_FALSE)
    var endJump = self.emitJump(OP_JUMP)
    self.patchJump(elseJump)
    self.emitByte(OP_POP)
    self.parsePrecedence(PREC_OR)
    self.patchJump(endJump)


proc statement(self: Compiler) =
    if self.parser.match(VAR):
        self.varDeclaration()
    elif self.parser.match(TokenType.FOR):
        self.forStatement()
    elif self.parser.match(IF):
        self.ifStatement()
    elif self.parser.match(TokenType.WHILE):
        self.whileStatement()
    elif self.parser.match(BREAK):
        self.parseBreak()
    elif self.parser.match(LB):
        self.beginScope()
        self.parseBlock()
        self.endScope()
    else:
        self.expressionStatement()



proc declaration(self: Compiler) =
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
    makeRule(nil, parseAnd, PREC_AND), # AND
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
    makeRule(nil, parseOr, PREC_OR), # OR
    makeRule(literal, nil, PREC_NONE), # TRUE
    makeRule(nil, nil, PREC_NONE), # VAR
    makeRule(nil, nil, PREC_NONE), # WHILE
    makeRule(deleteVariable, nil, PREC_NONE), # DEL
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
