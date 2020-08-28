import strutils
import algorithm
import strformat
import lexer
import common
import meta/chunk
import meta/tokenobject
import meta/valueobject
import meta/tokentype
import meta/looptype
import types/stringtype
import types/functiontype


type
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

    ParseFn = proc(self: var Compiler, canAssign: bool): void

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


proc compileError(self: var Compiler, message: string) =
    echo &"CompileError at line {self.parser.peek().line}: {message}"
    self.parser.hadError = true


proc emitByte(self: var Compiler, byt: OpCode|uint8) =
    self.function.chunk.writeChunk(uint8 byt, self.parser.previous().line)


proc emitBytes(self: var Compiler, byt1: OpCode|uint8, byt2: OpCode|uint8) =
    self.emitByte(uint8 byt1)
    self.emitByte(uint8 byt2)


proc emitBytes(self: var Compiler, bytarr: array[3, uint8]) =
    self.emitBytes(bytarr[0], bytarr[1])
    self.emitByte(bytarr[2])


proc makeConstant(self: var Compiler, val: Value): uint8 =
    result = uint8 self.function.chunk.addConstant(val)


proc makeLongConstant(self: var Compiler, val: Value): array[3, uint8] =
    result = self.function.chunk.writeConstant(val)


proc emitConstant(self: var Compiler, value: Value) =
    if self.function.chunk.consts.values.len > 255:
        self.emitByte(OP_CONSTANT_LONG)
        self.emitBytes(self.makeLongConstant(value))
    else:
        self.emitBytes(OP_CONSTANT, self.makeConstant(value))


proc getRule(kind: TokenType): ParseRule  # Forward declarations
proc statement(self: var Compiler)
proc declaration(self: var Compiler)


proc endCompiler(self: var Compiler): ptr Function =
    self.emitByte(OP_RETURN)
    return self.function


proc parsePrecedence(self: var Compiler, precedence: Precedence) =
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


proc expression(self: var Compiler) =
    self.parsePrecedence(PREC_ASSIGNMENT)


proc binary(self: var Compiler, canAssign: bool) =
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


proc unary(self: var Compiler, canAssign: bool) =
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


template markObject*(self, obj: untyped): untyped =
    obj.next = self.vm.objects
    self.vm.objects = obj
    obj


proc strVal(self: var Compiler, canAssign: bool) =
    var str = self.parser.previous().lexeme
    var delimiter = &"{str[0]}"
    str = str.unescape(delimiter, delimiter)
    self.emitConstant(Value(kind: OBJECT, obj: self.markObject(newString(str))))


proc bracketAssign(self: var Compiler, canAssign: bool) =
    discard # TODO -> Implement this


proc bracket(self: var Compiler, canAssign: bool) =
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
    if self.parser.peek.kind == EQ:
        discard self.parser.advance()
        self.parsePrecedence(PREC_TERM)
    self.parser.consume(TokenType.RS, "Expecting ']' after slice expression")


proc literal(self: var Compiler, canAssign: bool) =
    case self.parser.previous().kind:
        of TRUE:
            self.emitByte(OP_TRUE)
        of FALSE:
            self.emitByte(OP_FALSE)
        of TokenType.NIL:
            self.emitByte(OP_NIL)
        else:
            discard  # Unreachable


proc number(self: var Compiler, canAssign: bool) =
    var value = self.parser.previous().literal
    self.emitConstant(value)


proc grouping(self: var Compiler, canAssign: bool) =
    if self.parser.match(EOF):
        self.parser.parseError(self.parser.previous, "Expecting ')'")
    elif self.parser.match(RP):
        self.emitByte(OP_NIL)
    else:
        self.expression()
        self.parser.consume(RP, "Expecting ')' after parentheszed expression")


proc synchronize(self: var Compiler) =
    self.parser.panicMode = false
    while self.parser.peek.kind != EOF:
        if self.parser.previous().kind == SEMICOLON:
            return
        case self.parser.peek.kind:
            of TokenType.CLASS, FUN, VAR, TokenType.FOR, IF, TokenType.WHILE, RETURN:
                return
            else:
                discard
        discard self.parser.advance()


proc identifierConstant(self: var Compiler, tok: Token): uint8 =
    return self.makeConstant(Value(kind: OBJECT, obj: self.markObject(newString(tok.lexeme))))


proc identifierLongConstant(self: var Compiler, tok: Token): array[3, uint8] =
    return self.makeLongConstant(Value(kind: OBJECT, obj: self.markObject(newString(tok.lexeme))))


proc addLocal(self: var Compiler, name: Token) =
    var local = Local(name: name, depth: self.scopeDepth)
    inc(self.localCount)
    self.locals.add(local)


proc declareVariable(self: var Compiler) =
    if self.scopeDepth == 0:
        return
    var name = self.parser.previous()
    self.addLocal(name)


proc parseVariable(self: var Compiler, message: string): uint8 =
    self.parser.consume(ID, message)
    self.declareVariable()
    if self.scopeDepth > 0:
        return uint8 0
    return self.identifierConstant(self.parser.previous)


proc parseLongVariable(self: var Compiler, message: string): array[3, uint8] =
    self.parser.consume(ID, message)
    self.declareVariable()
    if self.scopeDepth > 0:
        return [uint8 0, uint8 0, uint8 0]
    return self.identifierLongConstant(self.parser.previous)


proc defineVariable(self: var Compiler, idx: uint8) =
    if self.scopeDepth > 0:
        return
    self.emitBytes(OP_DEFINE_GLOBAL, idx)


proc defineVariable(self: var Compiler, idx: array[3, uint8]) =
    if self.scopeDepth > 0:
        return
    self.emitByte(OP_DEFINE_GLOBAL)
    self.emitBytes(idx)


proc resolveLocal(self: var Compiler, name: Token): int =
    var i = self.localCount - 1
    for local in reversed(self.locals):
        if local.name.lexeme == name.lexeme:
            return i
        i = i - 1
    return -1


proc namedVariable(self: var Compiler, tok: Token, canAssign: bool) =
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


proc namedLongVariable(self: var Compiler, tok: Token, canAssign: bool) =
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



proc variable(self: var Compiler, canAssign: bool) =
    if self.locals.len < 255:
        self.namedVariable(self.parser.previous(), canAssign)
    else:
        self.namedLongVariable(self.parser.previous(), canAssign)


proc varDeclaration(self: var Compiler) =
    var shortName: uint8
    var longName: array[3, uint8]
    var useShort: bool = true
    if self.function.chunk.consts.values.len < 255:
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


proc expressionStatement(self: var Compiler) =
    self.expression()
    self.parser.consume(SEMICOLON, "Missing semicolon after expression")
    self.emitByte(OP_POP)


proc deleteVariable(self: var Compiler, canAssign: bool) =
    self.expression()
    if self.parser.previous().kind in [NUMBER, STR]:
        self.compileError("cannot delete a literal")
    var code: OpCode
    if self.scopeDepth == 0:
        code = OP_DELETE_GLOBAL
    else:
        code = OP_DELETE_LOCAL
    self.localCount = self.localCount - 1
    if self.function.chunk.consts.values.len < 255:
        var name = self.identifierConstant(self.parser.previous())
        self.locals.delete(name)
        self.emitBytes(code, name)
    else:
        var name = self.identifierLongConstant(self.parser.previous())
        self.emitBytes(code, name[0])
        self.emitBytes(name[1], name[2])


proc parseBlock(self: var Compiler) =
    while not self.parser.check(RB) and not self.parser.check(EOF):
        self.declaration()
    self.parser.consume(RB, "Expecting '}' after block statement")


proc beginScope(self: var Compiler) =
    inc(self.scopeDepth)


proc endScope(self: var Compiler) =
    self.scopeDepth = self.scopeDepth - 1
    while self.localCount > 0 and self.locals[self.localCount - 1].depth > self.scopeDepth:
        self.emitByte(OP_POP)
        self.localCount = self.localCount - 1


proc emitJump(self: var Compiler, opcode: OpCode): int =
    self.emitByte(opcode)
    self.emitByte(0xff)
    self.emitByte(0xff)
    return self.function.chunk.code.len - 2


proc patchJump(self: var Compiler, offset: int) =
    var jump = self.function.chunk.code.len - offset - 2
    if jump > (int uint16.high):
        self.compileError("too much code to jump over")
    else:
        self.function.chunk.code[offset] = uint8 (jump shr 8) and 0xff
        self.function.chunk.code[offset + 1] = uint8 jump and 0xff


proc ifStatement(self: var Compiler) =
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


proc emitLoop(self: var Compiler, start: int) =
    self.emitByte(OP_LOOP)
    var offset = self.function.chunk.code.len - start + 2
    if offset > (int uint16.high):
        self.compileError("loop body is too large")
    else:
        self.emitByte(uint8 (offset shr 8) and 0xff)
        self.emitByte(uint8 offset and 0xff)


proc endLooping(self: var Compiler) =
    if self.loop.loopEnd != -1:
        self.patchJump(self.loop.loopEnd)
        self.emitByte(OP_POP)
    var i = self.loop.body
    while i < self.function.chunk.code.len:
        if self.function.chunk.code[i] == uint OP_BREAK:
            self.function.chunk.code[i] = uint8 OP_JUMP
            self.patchJump(i + 1)
            i += 3
        else:
            i += 1
    self.loop = self.loop.outer


proc whileStatement(self: var Compiler) =
    var loop = Loop(depth: self.scopeDepth, outer: self.loop, start: self.function.chunk.code.len, alive: true, loopEnd: -1)
    self.loop = loop
    self.parser.consume(LP, "The loop condition must be parenthesized")
    if self.parser.peek.kind != EOF:
        self.expression()
        if self.parser.peek.kind != EOF:
            self.parser.consume(RP, "The loop condition must be parenthesized")
        if self.parser.peek.kind != EOF:
            self.loop.loopEnd = self.emitJump(OP_JUMP_IF_FALSE)
            self.emitByte(OP_POP)
            self.loop.body = self.function.chunk.code.len
            self.statement()
            self.emitLoop(self.loop.start)
            self.patchJump(self.loop.loopEnd)
            self.emitByte(OP_POP)
        else:
            self.parser.parseError(self.parser.previous, "Invalid syntax")
    else:
        self.parser.parseError(self.parser.previous, "The loop condition must be parenthesized")
    self.endLooping()


proc forStatement(self: var Compiler) =
    self.beginScope()
    self.parser.consume(LP, "The loop condition must be parenthesized")
    if self.parser.peek.kind != EOF:
        if self.parser.match(SEMICOLON):
            discard
        elif self.parser.match(VAR):
            self.varDeclaration()
        else:
            self.expressionStatement()
        var loop = Loop(depth: self.scopeDepth, outer: self.loop, start: self.function.chunk.code.len, alive: true, loopEnd: -1)
        self.loop = loop
        if not self.parser.match(SEMICOLON):
            self.expression()
            if self.parser.previous.kind != EOF:
                self.parser.consume(SEMICOLON, "Expecting ';'")
                self.loop.loopEnd = self.emitJump(OP_JUMP_IF_FALSE)
                self.emitByte(OP_POP)
            else:
                self.parser.current -= 1
                self.parser.parseError(self.parser.previous, "Invalid syntax")
        if not self.parser.match(RP):
            var bodyJump = self.emitJump(OP_JUMP)
            var incrementStart = self.function.chunk.code.len
            if self.parser.peek.kind != EOF:
                self.expression()
                self.emitByte(OP_POP)
                self.parser.consume(RP, "The loop condition must be parenthesized")
                self.emitLoop(self.loop.start)
                self.loop.start = incrementStart
                self.patchJump(bodyJump)
        if self.parser.peek.kind != EOF:
            self.loop.body = self.function.chunk.code.len
            self.statement()
            self.emitLoop(self.loop.start)
        else:
            self.parser.current -= 1
            self.parser.parseError(self.parser.previous, "Invalid syntax")
        if self.loop.loopEnd != -1:
            self.patchJump(self.loop.loopEnd)
            self.emitByte(OP_POP)
    else:
        self.parser.parseError(self.parser.previous, "The loop condition must be parenthesized")
    self.endLooping()
    self.endScope()


proc parseBreak(self: var Compiler) =
    if not self.loop.alive:
        self.parser.parseError(self.parser.previous, "'break' outside loop")
    else:
        self.parser.consume(SEMICOLON, "missing semicolon after statement")
        var i = self.localCount - 1
        while i >= 0 and self.locals[i].depth > self.loop.depth:
            self.emitByte(OP_POP)
            i -= 1
        discard self.emitJump(OP_BREAK)

proc parseAnd(self: var Compiler, canAssign: bool) =
    var jump = self.emitJump(OP_JUMP_IF_FALSE)
    self.emitByte(OP_POP)
    self.parsePrecedence(PREC_AND)
    self.patchJump(jump)


proc parseOr(self: var Compiler, canAssign: bool) =
    var elseJump = self.emitJump(OP_JUMP_IF_FALSE)
    var endJump = self.emitJump(OP_JUMP)
    self.patchJump(elseJump)
    self.emitByte(OP_POP)
    self.parsePrecedence(PREC_OR)
    self.patchJump(endJump)


proc continueStatement(self: var Compiler) =
    if not self.loop.alive:
        self.parser.parseError(self.parser.previous, "'continue' outside loop")
    else:
        self.parser.consume(SEMICOLON, "missing semicolon after statement")
        var i = self.localCount - 1
        while i >= 0 and self.locals[i].depth > self.loop.depth:
            self.emitByte(OP_POP)
            i -= 1
        self.emitLoop(self.loop.start)


proc statement(self: var Compiler) =
    if self.parser.match(VAR):
        self.varDeclaration()
    elif self.parser.match(TokenType.FOR):
        self.forStatement()
    elif self.parser.match(IF):
        self.ifStatement()
    elif self.parser.match(TokenType.WHILE):
        self.whileStatement()
    elif self.parser.match(CONTINUE):
        self.continueStatement()
    elif self.parser.match(BREAK):
        self.parseBreak()
    elif self.parser.match(LB):
        self.beginScope()
        self.parseBlock()
        self.endScope()
    else:
        self.expressionStatement()


proc declaration(self: var Compiler) =
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
    makeRule(nil, nil, PREC_NONE), # CONTINUE
]


proc getRule(kind: TokenType): ParseRule =
    result = rules[kind]


proc compile*(self: var Compiler, source: string): ptr Function =
    var scanner = initLexer(source)
    var tokens = scanner.lex()
    if len(tokens) > 1 and not scanner.errored:
        self.parser = initParser(tokens)
        while not self.parser.match(EOF):
            self.declaration()
        var function = self.endCompiler()
        if not self.parser.hadError:
            return function
        else:
            return nil
    else:
        return nil


proc initCompiler*(vm: var VM, context: FunctionType): Compiler =
    result = Compiler(parser: initParser(@[]), function: nil, locals: @[], scopeDepth: 0, localCount: 0, loop: Loop(alive: false, loopEnd: -1), vm: vm, context: context)
    result.locals.add(Local(depth: 0, name: Token(kind: EOF, lexeme: "")))
    inc(result.localCount)
    result.function = result.markObject(newFunction())
